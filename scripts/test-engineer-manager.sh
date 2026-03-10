#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

echo "=== Test: Engineer Manager ==="

# 1. Trigger docs-engineer via workflow_dispatch
echo "Triggering docs-engineer workflow..."
gh workflow run "claude-engineer-managers.yml" \
  --repo "$GITHUB_REPOSITORY" \
  -f engineer="docs-engineer"

# Wait for it to appear in the run list
sleep 15
RUN_ID=$(gh run list \
  --repo "$GITHUB_REPOSITORY" \
  --workflow "claude-engineer-managers.yml" \
  --json databaseId,status \
  --jq '[.[] | select(.status != "completed")] | .[0].databaseId // empty')

if [ -z "$RUN_ID" ]; then
  # Maybe it already completed quickly, check most recent
  RUN_ID=$(gh run list \
    --repo "$GITHUB_REPOSITORY" \
    --workflow "claude-engineer-managers.yml" \
    --limit 1 \
    --json databaseId --jq '.[0].databaseId // empty')
fi

if [ -z "$RUN_ID" ]; then
  print_result "FAIL" "Could not find engineer manager workflow run"
  exit 1
fi

echo "Engineer run: $RUN_ID"
wait_for_completion "$RUN_ID" 1800  # Engineers can take a while

# 2. Verify dashboard issue exists
DASHBOARD=$(gh issue list \
  --repo "$GITHUB_REPOSITORY" \
  --label "integration-test:docs-engineer" \
  --state open \
  --json number --jq '.[0].number // empty')

if [ -z "$DASHBOARD" ]; then
  print_result "FAIL" "No dashboard issue found with label integration-test:docs-engineer"
  exit 1
fi
echo "Dashboard issue #$DASHBOARD found"

print_result "PASS" "Engineer manager working"
