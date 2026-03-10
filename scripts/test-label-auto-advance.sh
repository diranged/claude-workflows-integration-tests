#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

echo "=== Test: Full Auto-Advance Pipeline ==="

# 1. Create test issue
ISSUE=$(create_test_issue \
  "Auto-Advance Pipeline Test" \
  "Create a file called integration-test.txt containing 'Auto-advance test passed'.")
echo "Created issue #$ISSUE"
trap "cleanup_test_issue $ISSUE" EXIT

# 2. Apply claude:design + claude:auto_advance (triggers full pipeline)
echo "Applying claude:design and claude:auto_advance labels to issue #$ISSUE..."
gh issue edit "$ISSUE" \
  --repo "$GITHUB_REPOSITORY" \
  --add-label "claude:design" --add-label "claude:auto_advance"

# 3. Wait for design phase
echo "--- Phase 1: Design ---"
RUN_ID=$(wait_for_triggered_run "claude-engineers.yml" 120)
echo "Design run: $RUN_ID"
wait_for_completion "$RUN_ID" 600

# 4. Wait for review phase (auto-triggered by designer adding claude:review)
echo "--- Phase 2: Review ---"
sleep 15
RUN_ID=$(wait_for_triggered_run "claude-engineers.yml" 180)
echo "Review run: $RUN_ID"
wait_for_completion "$RUN_ID" 600

# 5. Wait for implement phase (auto-triggered by architect adding claude:implement)
echo "--- Phase 3: Implement ---"
sleep 15
RUN_ID=$(wait_for_triggered_run "claude-engineers.yml" 180)
echo "Implement run: $RUN_ID"
wait_for_completion "$RUN_ID" 600

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

print_result "PASS" "Full auto-advance pipeline working"
