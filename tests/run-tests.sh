#!/usr/bin/env bash
# run-tests.sh — Main test runner for homelab-stack
# Usage: tests/run-tests.sh [--stack <name>] [--all] [--help]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=tests/lib/report.sh
source "${SCRIPT_DIR}/lib/report.sh"

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --stack <name>    Run tests for a specific stack (base, monitoring, sso, media,
                    network, productivity, ai, databases, notifications, storage)
  --all             Run all stack tests and e2e tests
  --e2e             Run only end-to-end tests
  --help            Show this help message

Examples:
  $(basename "$0") --stack base
  $(basename "$0") --all
  $(basename "$0") --e2e
EOF
}

run_test_file() {
  local test_file="$1"
  local suite_name
  suite_name=$(basename "$test_file" .test.sh)

  if [[ ! -f "$test_file" ]]; then
    echo "Test file not found: ${test_file}"
    return 1
  fi

  local before_pass=$ASSERT_PASS
  local before_fail=$ASSERT_FAIL
  local before_skip=$ASSERT_SKIP

  # Source the lib files
  # shellcheck source=tests/lib/assert.sh
  source "${SCRIPT_DIR}/lib/assert.sh"
  # shellcheck source=tests/lib/docker.sh
  source "${SCRIPT_DIR}/lib/docker.sh"
  # shellcheck source=tests/lib/wait-healthy.sh
  source "${SCRIPT_DIR}/lib/wait-healthy.sh"

  export REPO_ROOT

  report_suite_start "$suite_name"

  # Run the test file
  # shellcheck disable=SC1090
  source "$test_file"

  local suite_pass=$((ASSERT_PASS - before_pass))
  local suite_fail=$((ASSERT_FAIL - before_fail))
  local suite_skip=$((ASSERT_SKIP - before_skip))

  report_suite_end "$suite_pass" "$suite_fail" "$suite_skip"

  TOTAL_PASS=$((TOTAL_PASS + suite_pass))
  TOTAL_FAIL=$((TOTAL_FAIL + suite_fail))
  TOTAL_SKIP=$((TOTAL_SKIP + suite_skip))
}

STACKS=(base monitoring sso media network productivity ai databases notifications storage)
E2E_TESTS=(sso-flow backup-restore)

MODE=""
TARGET_STACK=""

if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)
      MODE="stack"
      TARGET_STACK="$2"
      shift 2
      ;;
    --all)
      MODE="all"
      shift
      ;;
    --e2e)
      MODE="e2e"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Initialize assertion counters
# shellcheck source=tests/lib/assert.sh
source "${SCRIPT_DIR}/lib/assert.sh"

case "$MODE" in
  stack)
    if [[ -z "$TARGET_STACK" ]]; then
      echo "Error: --stack requires a stack name"
      usage
      exit 1
    fi
    test_file="${SCRIPT_DIR}/stacks/${TARGET_STACK}.test.sh"
    run_test_file "$test_file"
    ;;
  all)
    for stack in "${STACKS[@]}"; do
      test_file="${SCRIPT_DIR}/stacks/${stack}.test.sh"
      if [[ -f "$test_file" ]]; then
        run_test_file "$test_file"
      fi
    done
    for e2e in "${E2E_TESTS[@]}"; do
      test_file="${SCRIPT_DIR}/e2e/${e2e}.test.sh"
      if [[ -f "$test_file" ]]; then
        run_test_file "$test_file"
      fi
    done
    ;;
  e2e)
    for e2e in "${E2E_TESTS[@]}"; do
      test_file="${SCRIPT_DIR}/e2e/${e2e}.test.sh"
      if [[ -f "$test_file" ]]; then
        run_test_file "$test_file"
      fi
    done
    ;;
esac

report_write_json "$TOTAL_PASS" "$TOTAL_FAIL" "$TOTAL_SKIP"
report_final_summary "$TOTAL_PASS" "$TOTAL_FAIL" "$TOTAL_SKIP"
