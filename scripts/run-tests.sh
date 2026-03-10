#!/bin/bash
# Main test runner - runs all integration tests sequentially
# Usage: ./scripts/run-tests.sh [test-name...]
# If no test names provided, runs all tests.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TESTS=("$@")
FAILURES=()

if [ ${#TESTS[@]} -eq 0 ]; then
  TESTS=(
    "mention-responder"
    "label-design"
    "label-auto-advance"
    "engineer-manager"
  )
fi

echo "============================================"
echo "Integration Test Suite"
echo "Repository: ${GITHUB_REPOSITORY:-local}"
echo "Tests: ${TESTS[*]}"
echo "============================================"
echo ""

for test in "${TESTS[@]}"; do
  script="$SCRIPT_DIR/test-${test}.sh"
  if [ ! -f "$script" ]; then
    echo "ERROR: Test script not found: $script"
    FAILURES+=("$test")
    continue
  fi

  echo "--- Running: $test ---"
  if bash "$script"; then
    echo ""
  else
    echo "[FAIL] $test"
    FAILURES+=("$test")
    echo ""
  fi
done

echo "============================================"
echo "Results Summary"
echo "============================================"

if [ ${#FAILURES[@]} -eq 0 ]; then
  echo "All ${#TESTS[@]} tests passed!"
  exit 0
else
  echo "${#FAILURES[@]} of ${#TESTS[@]} tests failed:"
  for f in "${FAILURES[@]}"; do
    echo "  - $f"
  done
  exit 1
fi
