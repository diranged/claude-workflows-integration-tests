#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

echo "=== Test: Formatting Enforcement ==="

# Track seen run IDs
SEEN_RUNS=""

# 1. Create test issue that requires writing TypeScript code
ISSUE=$(create_test_issue \
  "Formatting Enforcement Test" \
  "Add a new TypeScript file at src/utils.ts that exports a function called add(a: number, b: number): number that returns the sum of two numbers. Include a JSDoc comment on the function.")
echo "Created issue #$ISSUE"
trap "cleanup_test_issue $ISSUE" EXIT

# 2. Apply claude:design + claude:auto_advance
echo "Applying claude:design and claude:auto_advance labels to issue #$ISSUE..."
gh issue edit "$ISSUE" \
  --repo "$GITHUB_REPOSITORY" \
  --add-label "claude:design" --add-label "claude:auto_advance"

# 3. Wait for design phase
echo "--- Phase 1: Design ---"
RUN_ID=$(wait_for_triggered_run "claude-engineers.yml" 120)
SEEN_RUNS="$RUN_ID"
echo "Design run: $RUN_ID"
wait_for_completion "$RUN_ID" 1200

# 4. Wait for review phase
echo "--- Phase 2: Review ---"
sleep 30
RUN_ID=$(wait_for_new_run "claude-engineers.yml" "$SEEN_RUNS" 300)
SEEN_RUNS="$SEEN_RUNS,$RUN_ID"
echo "Review run: $RUN_ID"
wait_for_completion "$RUN_ID" 1200

# 5. Wait for implement phase
echo "--- Phase 3: Implement ---"
sleep 30
RUN_ID=$(wait_for_new_run "claude-engineers.yml" "$SEEN_RUNS" 300)
SEEN_RUNS="$SEEN_RUNS,$RUN_ID"
echo "Implement run: $RUN_ID"
wait_for_completion "$RUN_ID" 1200

# 6. Verify PR was created
echo "Checking for PR linked to issue #$ISSUE..."
PR=$(gh pr list \
  --repo "$GITHUB_REPOSITORY" \
  --json number,body \
  --jq ".[] | select(.body | contains(\"#$ISSUE\")) | .number" | head -1)

if [ -z "$PR" ]; then
  print_result "FAIL" "No PR created linking to issue #$ISSUE"
  exit 1
fi
echo "PR #$PR created successfully"

# 7. Wait for CI to run on the PR
echo "Waiting for CI to run on PR #$PR..."
sleep 30
CI_RUN=$(gh run list \
  --repo "$GITHUB_REPOSITORY" \
  --workflow "ci.yml" \
  --limit 5 \
  --json databaseId,headBranch,status \
  --jq "[.[] | select(.status != \"completed\")] | .[0].databaseId // empty" 2>/dev/null || true)

if [ -z "$CI_RUN" ]; then
  # CI might have already completed, check the latest
  CI_RUN=$(gh run list \
    --repo "$GITHUB_REPOSITORY" \
    --workflow "ci.yml" \
    --limit 1 \
    --json databaseId \
    --jq '.[0].databaseId' 2>/dev/null || true)
fi

if [ -n "$CI_RUN" ]; then
  echo "CI run: $CI_RUN"
  # Wait for CI completion
  gh run watch "$CI_RUN" --repo "$GITHUB_REPOSITORY" --interval 10 2>/dev/null || true

  CI_CONCLUSION=$(gh run view "$CI_RUN" --repo "$GITHUB_REPOSITORY" --json conclusion --jq '.conclusion')
  echo "CI conclusion: $CI_CONCLUSION"

  if [ "$CI_CONCLUSION" = "success" ]; then
    print_result "PASS" "Formatting enforcement working — PR #$PR passes CI formatting check"
  else
    print_result "FAIL" "PR #$PR failed CI (conclusion: $CI_CONCLUSION) — agent may not have run prettier"
    exit 1
  fi
else
  echo "Warning: Could not find CI run for PR #$PR"
  print_result "WARN" "PR created but could not verify CI formatting check"
fi
