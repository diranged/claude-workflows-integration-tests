#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

echo "=== Test: Full Auto-Advance Pipeline ==="

# 1. Create test issue
ISSUE=$(create_test_issue \
  "Auto-Advance Pipeline Test" \
  "Create a file called integration-test.txt at the root of the repository with the content 'Auto-advance test passed'. Nothing else.")
echo "Created issue #$ISSUE"
trap "cleanup_test_issue $ISSUE" EXIT

# 2. Apply claude:design + claude:auto_advance
echo "Applying claude:design and claude:auto_advance labels to issue #$ISSUE..."
gh issue edit "$ISSUE" \
  --repo "$GITHUB_REPOSITORY" \
  --add-label "claude:design" --add-label "claude:auto_advance"

# 3. Wait for design phase to complete (label changes from design to review)
echo "--- Phase 1: Design ---"
wait_for_label "$ISSUE" "claude:review" 600
echo "Design phase completed — issue advanced to review"

# 4. Wait for review phase to complete (label changes from review to implement)
echo "--- Phase 2: Review ---"
wait_for_label "$ISSUE" "claude:implement" 1200
echo "Review phase completed — issue advanced to implement"

# 5. Wait for implementation to produce a PR
echo "--- Phase 3: Implement ---"
PR=$(wait_for_linked_pr "$ISSUE" 600)
echo "Implementation complete — PR #$PR created"

# 6. Verify tracking comment exists
verify_tracking_comment "$ISSUE"

print_result "PASS" "Full auto-advance pipeline working — design → review → implement → PR #$PR"
