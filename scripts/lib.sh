#!/bin/bash
# Shared utilities for integration test scripts

set -euo pipefail

# Create a test issue with unique identifier
# Usage: create_test_issue "Title Suffix" "Body text"
# Returns: issue number
create_test_issue() {
  local title="$1"
  local body="$2"
  local run_id="${GITHUB_RUN_ID:-local}"
  local timestamp
  timestamp=$(date +%s)

  gh issue create \
    --repo "$GITHUB_REPOSITORY" \
    --title "[Integration Test] $title - $run_id-$timestamp" \
    --body "$body" \
    --json number --jq '.number'
}

# Wait for a workflow run triggered after a given timestamp
# Usage: wait_for_triggered_run "workflow-name.yml" [max_wait_seconds]
# Returns: run ID
wait_for_triggered_run() {
  local workflow="$1"
  local max_wait="${2:-300}"
  local start_time
  start_time=$(date +%s)
  local start_iso
  start_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  echo "Waiting for workflow '$workflow' to trigger (max ${max_wait}s)..." >&2

  # Give GitHub time to process the event
  sleep 15

  local elapsed=15
  while [ "$elapsed" -lt "$max_wait" ]; do
    local run_id
    run_id=$(gh run list \
      --repo "$GITHUB_REPOSITORY" \
      --workflow "$workflow" \
      --json databaseId,status,createdAt \
      --jq "[.[] | select(.createdAt > \"$start_iso\")] | .[0].databaseId // empty" 2>/dev/null || true)

    if [ -n "$run_id" ]; then
      echo "$run_id"
      return 0
    fi

    sleep 5
    elapsed=$((elapsed + 5))
  done

  echo "ERROR: No triggered workflow run found for '$workflow' within ${max_wait}s" >&2
  return 1
}

# Wait for a workflow run to complete
# Usage: wait_for_completion <run_id> [max_wait_seconds]
wait_for_completion() {
  local run_id="$1"
  local max_wait="${2:-600}"

  echo "Waiting for run $run_id to complete (max ${max_wait}s)..." >&2
  gh run watch "$run_id" \
    --repo "$GITHUB_REPOSITORY" \
    --exit-status \
    --interval 10 || {
    local status
    status=$(gh run view "$run_id" --repo "$GITHUB_REPOSITORY" --json conclusion --jq '.conclusion')
    echo "ERROR: Run $run_id finished with conclusion: $status" >&2
    return 1
  }
}

# Verify issue has a tracking comment from Claude
# Usage: verify_tracking_comment <issue_number>
verify_tracking_comment() {
  local issue_number="$1"
  local comments
  comments=$(gh api "/repos/$GITHUB_REPOSITORY/issues/$issue_number/comments" \
    --jq '[.[] | select(.body | contains("claude-tracking-comment") or contains("Status:"))] | length')

  if [ "$comments" -gt 0 ]; then
    echo "Found $comments tracking comment(s) on issue #$issue_number" >&2
    return 0
  else
    echo "ERROR: No tracking comments found on issue #$issue_number" >&2
    return 1
  fi
}

# Clean up test issue and any associated PRs/branches
# Usage: cleanup_test_issue <issue_number>
cleanup_test_issue() {
  local issue_number="$1"
  echo "Cleaning up test issue #$issue_number..." >&2

  # Close issue
  gh issue close "$issue_number" \
    --repo "$GITHUB_REPOSITORY" \
    --comment "Integration test cleanup" 2>/dev/null || true

  # Find and close any PRs linking to this issue
  gh pr list \
    --repo "$GITHUB_REPOSITORY" \
    --json number,body \
    --jq ".[] | select(.body | contains(\"#$issue_number\")) | .number" 2>/dev/null | \
    while read -r pr; do
      if [ -n "$pr" ]; then
        echo "Closing PR #$pr..." >&2
        gh pr close "$pr" \
          --repo "$GITHUB_REPOSITORY" \
          --delete-branch 2>/dev/null || true
      fi
    done
}

# Print test result
# Usage: print_result "PASS" "Test description"
print_result() {
  local status="$1"
  local description="$2"
  echo "[$status] $description"
}
