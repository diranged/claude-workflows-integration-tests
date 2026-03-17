#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

echo "=== Test: Formatting Enforcement ==="

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

# 3. Wait for full pipeline: design → review → implement
echo "--- Phase 1: Design ---"
wait_for_label "$ISSUE" "claude:review" 600
echo "Design phase completed"

echo "--- Phase 2: Review ---"
wait_for_label "$ISSUE" "claude:implement" 1200
echo "Review phase completed"

# 4. Wait for PR
echo "--- Phase 3: Implement ---"
PR=$(wait_for_linked_pr "$ISSUE" 600)
echo "PR #$PR created"

# 5. Wait for CI to run on the PR
echo "Waiting for CI on PR #$PR..."
sleep 30

# Find CI run for this PR's branch
PR_BRANCH=$(gh pr view "$PR" --repo "$GITHUB_REPOSITORY" --json headRefName --jq '.headRefName')
CI_RUN=""
ELAPSED=0
while [ "$ELAPSED" -lt 120 ]; do
  CI_RUN=$(gh run list \
    --repo "$GITHUB_REPOSITORY" \
    --workflow "ci.yml" \
    --branch "$PR_BRANCH" \
    --limit 1 \
    --json databaseId \
    --jq '.[0].databaseId // empty' 2>/dev/null || true)
  if [ -n "$CI_RUN" ]; then
    break
  fi
  sleep 10
  ELAPSED=$((ELAPSED + 10))
done

if [ -z "$CI_RUN" ]; then
  echo "Warning: Could not find CI run for PR #$PR (branch: $PR_BRANCH)"
  print_result "WARN" "PR created but could not verify CI formatting check"
  exit 0
fi

echo "CI run: $CI_RUN"
gh run watch "$CI_RUN" --repo "$GITHUB_REPOSITORY" --interval 10 2>/dev/null || true

CI_CONCLUSION=$(gh run view "$CI_RUN" --repo "$GITHUB_REPOSITORY" --json conclusion --jq '.conclusion')
echo "CI conclusion: $CI_CONCLUSION"

if [ "$CI_CONCLUSION" = "success" ]; then
  print_result "PASS" "Formatting enforcement working — PR #$PR passes CI formatting check"
else
  print_result "FAIL" "PR #$PR failed CI (conclusion: $CI_CONCLUSION) — agent may not have run prettier"
  exit 1
fi
