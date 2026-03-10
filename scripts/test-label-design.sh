#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

echo "=== Test: Design Label Pipeline ==="

# 1. Create test issue
ISSUE=$(create_test_issue \
  "Design Pipeline Test" \
  "Create a simple shell script that prints 'hello world'. The script should be called hello.sh and placed in the root of the repository.")
echo "Created issue #$ISSUE"
trap "cleanup_test_issue $ISSUE" EXIT

# 2. Apply claude:design label (App token triggers workflow)
echo "Applying claude:design label to issue #$ISSUE..."
gh issue edit "$ISSUE" \
  --repo "$GITHUB_REPOSITORY" \
  --add-label "claude:design"

# 3. Wait for engineer workflow to trigger
echo "Waiting for Claude Engineers workflow..."
RUN_ID=$(wait_for_triggered_run "claude-engineers.yml" 120)
echo "Triggered run: $RUN_ID"

# 4. Wait for completion
wait_for_completion "$RUN_ID" 600

# 5. Verify design was posted (tracking comment)
verify_tracking_comment "$ISSUE"

# 6. Check label state
LABELS=$(gh issue view "$ISSUE" \
  --repo "$GITHUB_REPOSITORY" \
  --json labels --jq '.labels[].name')
if echo "$LABELS" | grep -q "claude:design"; then
  echo "WARN: claude:design label still present (may not have auto-advanced)"
fi

print_result "PASS" "Design label pipeline working"
