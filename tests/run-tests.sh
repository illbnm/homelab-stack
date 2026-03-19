#!/usr/bin/env bash
# =============================================================================
# run-tests.sh — HomeLab Stack Integration Test Runner
#
# Usage:
#   ./tests/run-tests.sh --all                 # Run all stack tests
#   ./tests/run-tests.sh --stack base           # Run a specific stack test
#   ./tests/run-tests.sh --stack base,media     # Run multiple stacks
#   ./tests/run-tests.sh --e2e                  # Run end-to-end tests
#   ./tests/run-tests.sh --level 1              # Run only Level 1 tests
#   ./tests/run-tests.sh --json results.json    # Output JSON report
# =============================================================================
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$TESTS_DIR/.."
export TESTS_DIR BASE_DIR

# Source libraries
source "$TESTS_DIR/lib/report.sh"
source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/docker.sh"

# Load environment variables
for env_file in "$BASE_DIR/.env" "$BASE_DIR/config/.env"; do
  if [[ -f "$env_file" ]]; then
    set -a
    source "$env_file"
    set +a
    break
  fi
done

# Defaults
RUN_ALL=false
RUN_E2E=false
STACKS=()
TEST_LEVEL=99
JSON_OUTPUT=""

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --all              Run all stack tests"
  echo "  --stack <name>     Run test(s) for specific stack(s), comma-separated"
  echo "  --e2e              Run end-to-end tests"
  echo "  --level <n>        Run only tests up to level n (1-4)"
  echo "  --json <file>      Write JSON report to file"
  echo "  -h, --help         Show this help"
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)       RUN_ALL=true; shift ;;
    --stack)     IFS=',' read -ra STACKS <<< "$2"; shift 2 ;;
    --e2e)       RUN_E2E=true; shift ;;
    --level)     TEST_LEVEL="$2"; shift 2 ;;
    --json)      JSON_OUTPUT="$2"; shift 2 ;;
    -h|--help)   usage ;;
    *)           echo "Unknown option: $1"; usage ;;
  esac
done

# Default to --all if nothing specified
if [[ "$RUN_ALL" == false && ${#STACKS[@]} -eq 0 && "$RUN_E2E" == false ]]; then
  RUN_ALL=true
fi

export TEST_LEVEL

# Preflight checks
echo -e "\033[1m🔍 HomeLab Stack Integration Tests\033[0m"
echo -e "\033[2m   $(date)\033[0m"

if ! command -v docker &>/dev/null; then
  echo "ERROR: docker is not installed or not in PATH"
  exit 1
fi

if ! docker info &>/dev/null 2>&1; then
  echo "ERROR: Docker daemon is not running"
  exit 1
fi

ALL_STACKS=(base databases sso network monitoring storage productivity media ai notifications)

run_stack_test() {
  local stack="$1"
  local test_file="$TESTS_DIR/stacks/${stack}.test.sh"
  if [[ -f "$test_file" ]]; then
    source "$test_file"
  else
    echo -e "\n\033[1;33m⚠ No test file for stack: $stack\033[0m"
  fi
}

# Run tests
if [[ "$RUN_ALL" == true ]]; then
  for stack in "${ALL_STACKS[@]}"; do
    run_stack_test "$stack"
  done
elif [[ ${#STACKS[@]} -gt 0 ]]; then
  for stack in "${STACKS[@]}"; do
    run_stack_test "$stack"
  done
fi

if [[ "$RUN_E2E" == true || "$RUN_ALL" == true ]]; then
  if [[ $TEST_LEVEL -ge 4 ]]; then
    for e2e_file in "$TESTS_DIR"/e2e/*.test.sh; do
      [[ -f "$e2e_file" ]] && source "$e2e_file"
    done
  fi
fi

# Summary
test_summary

if [[ -n "$JSON_OUTPUT" ]]; then
  test_report_json "$JSON_OUTPUT"
fi

# Exit code
[[ $_TOTAL_FAILED -eq 0 ]] && exit 0 || exit 1
