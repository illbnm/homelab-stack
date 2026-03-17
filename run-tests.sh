#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Integration Test Runner
# Usage: ./tests/run-tests.sh [--stack <name>] [--all] [--e2e] [--ci] [--help]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
STACKS_DIR="${SCRIPT_DIR}/stacks"
E2E_DIR="${SCRIPT_DIR}/e2e"

# shellcheck source=lib/assert.sh
source "${LIB_DIR}/assert.sh"
# shellcheck source=lib/docker.sh
source "${LIB_DIR}/docker.sh"
# shellcheck source=lib/report.sh
source "${LIB_DIR}/report.sh"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
RUN_ALL=false
RUN_E2E=false
RUN_CI=false
SELECTED_STACK=""
VERBOSE=false
OUTPUT_JSON=""
TIMEOUT=30

AVAILABLE_STACKS=(
  base
  media
  storage
  monitoring
  network
  productivity
  ai
  sso
  databases
  notifications
)

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --stack <name>      Run tests for a specific stack
  --all               Run tests for all stacks
  --e2e               Also run end-to-end tests
  --ci                CI mode (use docker-compose.test.yml, no real domains)
  --verbose           Print each test as it runs
  --json <file>       Write JSON report to file
  --timeout <sec>     HTTP/container wait timeout (default: 30)
  --help              Show this help

Available stacks:
  ${AVAILABLE_STACKS[*]}

Examples:
  $(basename "$0") --stack base
  $(basename "$0") --all --e2e --json report.json
  $(basename "$0") --all --ci
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stack)
        SELECTED_STACK="${2:?'--stack requires an argument'}"
        shift 2
        ;;
      --all)
        RUN_ALL=true
        shift
        ;;
      --e2e)
        RUN_E2E=true
        shift
        ;;
      --ci)
        RUN_CI=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --json)
        OUTPUT_JSON="${2:?'--json requires a filename'}"
        shift 2
        ;;
      --timeout)
        TIMEOUT="${2:?'--timeout requires a number'}"
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  # Validate
  if [[ -z "$SELECTED_STACK" && "$RUN_ALL" == "false" ]]; then
    log_error "Specify --stack <name> or --all"
    usage
    exit 1
  fi
  if [[ -n "$SELECTED_STACK" && "$RUN_ALL" == "true" ]]; then
    log_error "--stack and --all are mutually exclusive"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Run a single stack test file
# ---------------------------------------------------------------------------
run_stack_test() {
  local stack="$1"
  local test_file="${STACKS_DIR}/${stack}.test.sh"

  if [[ ! -f "$test_file" ]]; then
    log_warn "Test file not found: ${test_file} — skipping"
    report_suite_skip "$stack"
    return 0
  fi

  report_suite_start "$stack"

  # Export globals needed by test files
  export ASSERT_TIMEOUT="$TIMEOUT"
  export TEST_VERBOSE="$VERBOSE"
  export TEST_CI_MODE="$RUN_CI"
  export CURRENT_SUITE="$stack"

  # Source the test file in a subshell to isolate failures
  # but still capture the results via the report library (shared tmp)
  (
    # shellcheck source=/dev/null
    source "$test_file"
    run_suite_functions
  )

  report_suite_end "$stack"
}

# ---------------------------------------------------------------------------
# Discover and run all test_* functions in sourced file
# ---------------------------------------------------------------------------
run_suite_functions() {
  # Called from within the subshell that sourced the test file
  local funcs
  funcs=$(declare -F | awk '{print $3}' | grep '^test_')

  if [[ -z "$funcs" ]]; then
    log_warn "No test functions found in ${CURRENT_SUITE}"
    return 0
  fi

  while IFS= read -r fn; do
    run_single_test "$fn"
  done <<< "$funcs"
}

# ---------------------------------------------------------------------------
# Run a single test function and record pass/fail
# ---------------------------------------------------------------------------
run_single_test() {
  local fn="$1"
  local start_ns end_ns duration_ms

  start_ns=$(date +%s%N 2>/dev/null || echo 0)

  report_test_start "$fn"

  local output
  local rc=0
  output=$(
    set +e
    "$fn" 2>&1
    echo "EXIT:$?"
  )

  local exit_code
  exit_code=$(echo "$output" | tail -1 | sed 's/EXIT://')
  output=$(echo "$output" | head -n -1)

  end_ns=$(date +%s%N 2>/dev/null || echo 0)
  duration_ms=$(( (end_ns - start_ns) / 1000000 ))

  if [[ "$exit_code" == "0" ]]; then
    report_test_pass "$fn" "$duration_ms"
  else
    report_test_fail "$fn" "$duration_ms" "$output"
    rc=1
  fi

  return $rc
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  parse_args "$@"

  report_init "$OUTPUT_JSON"
  report_header "HomeLab Stack — Integration Test Suite"

  local stacks_to_run=()

  if [[ "$RUN_ALL" == "true" ]]; then
    stacks_to_run=("${AVAILABLE_STACKS[@]}")
  else
    stacks_to_run=("$SELECTED_STACK")
  fi

  for stack in "${stacks_to_run[@]}"; do
    run_stack_test "$stack"
  done

  # End-to-end tests
  if [[ "$RUN_E2E" == "true" ]]; then
    report_suite_start "e2e/sso-flow"
    (
      export ASSERT_TIMEOUT="$TIMEOUT"
      export TEST_VERBOSE="$VERBOSE"
      export TEST_CI_MODE="$RUN_CI"
      export CURRENT_SUITE="e2e/sso-flow"
      # shellcheck source=/dev/null
      source "${E2E_DIR}/sso-flow.test.sh"
      run_suite_functions
    )
    report_suite_end "e2e/sso-flow"

    report_suite_start "e2e/backup-restore"
    (
      export ASSERT_TIMEOUT="$TIMEOUT"
      export TEST_VERBOSE="$VERBOSE"
      export TEST_CI_MODE="$RUN_CI"
      export CURRENT_SUITE="e2e/backup-restore"
      # shellcheck source=/dev/null
      source "${E2E_DIR}/backup-restore.test.sh"
      run_suite_functions
    )
    report_suite_end "e2e/backup-restore"
  fi

  report_summary

  # Exit with non-zero if any test failed
  [[ "$(report_get_failed_count)" -eq 0 ]]
}

main "$@"
