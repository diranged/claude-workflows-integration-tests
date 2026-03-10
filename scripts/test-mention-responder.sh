#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

echo "=== Test: @claude Mention Responder ==="

# 1. Create test issue
ISSUE=$(create_test_issue \
  "Mention Responder Test" \
  "This is an automated integration test for the @claude mention responder flow.")
echo "Created issue #$ISSUE"
trap "cleanup_test_issue $ISSUE" EXIT

# 2. Post @claude comment (using App token so it triggers the responder workflow)
echo "Posting @claude comment on issue #$ISSUE..."
gh issue comment "$ISSUE" \
  --repo "$GITHUB_REPOSITORY" \
  --body "@claude Please respond with 'Integration test successful' and nothing else."

# 3. Wait for responder workflow to trigger
echo "Waiting for Claude Responder workflow..."
RUN_ID=$(wait_for_triggered_run "claude-responder.yml" 120)
echo "Triggered run: $RUN_ID"

# 4. Wait for completion
wait_for_completion "$RUN_ID" 300

# 5. Verify Claude responded with a tracking comment
verify_tracking_comment "$ISSUE"

print_result "PASS" "@claude mention responder working"
