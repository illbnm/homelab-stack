#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Integration Test Runner
# Usage: run-tests.sh [--stack <name>|--all] [--json] [--help]
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
STACKS_DIR="$BASE_DIR/stacks"
TESTS_DIR="$SCRIPT_DIR"

# Parse args
STACK=""
JSON_MODE=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --stack)  STACK="$2"; shift 2 ;;
    --all)    STACK="all"; shift ;;
    --json)   JSON_MODE=true; shift ;;
    --help|-h)
      cat <<'EOF'
Usage: run-tests.sh [options]

Options:
  --stack <name>   Run tests for a specific stack
  --all            Run tests for all stacks
  --json           Output results as JSON to tests/results/report.json
  --help           Show this help

Available stacks:
  base, databases, sso, monitoring, network, storage,
  productivity, media, ai, home-automation, notifications

Examples:
  ./tests/run-tests.sh --stack base
  ./tests/run-tests.sh --all
  ./tests/run-tests.sh --all --json
EOF
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

[[ -z "$STACK" ]] && { echo "Error: specify --stack <name> or --all"; exit 1; }

# Source report library
source "$TESTS_DIR/lib/report.sh"
export BASE_DIR

# ---------------------------------------------------------------------------
# Run tests for a stack
# ---------------------------------------------------------------------------
run_stack_tests() {
  local stack_name="$1"
  local test_file="$TESTS_DIR/stacks/${stack_name}.test.sh"

  if [[ ! -f "$test_file" ]]; then
    echo "  No tests found for stack: $stack_name"
    return
  fi

  report_stack "$stack_name"
  source "$test_file"

  # Find and run all test_* functions
  local test_funcs
  test_funcs=$(declare -F | grep 'declare -f test_' | awk '{print $3}')

  for func in $test_funcs; do
    local start_time end_time duration result
    start_time=$(date +%s%N)

    if result=$("$func" 2>&1); then
      end_time=$(date +%s%N)
      duration=$(echo "scale=1; ($end_time - $start_time) / 1000000000" | bc 2>/dev/null || echo "0")
      report_result "${func#test_}" "pass" "$duration"
    else
      end_time=$(date +%s%N)
      duration=$(echo "scale=1; ($end_time - $start_time) / 1000000000" | bc 2>/dev/null || echo "0")
      report_result "${func#test_}" "fail" "$duration" "$result"
    fi
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
report_init

if [[ "$STACK" == "all" ]]; then
  # Define stack order (dependencies first)
  local_order=(base databases sso monitoring network storage productivity media ai home-automation notifications)

  # Also run E2E tests
  for stack in "${local_order[@]}"; do
    if [[ -d "$STACKS_DIR/$stack" ]]; then
      run_stack_tests "$stack"
    fi
  done

  # Run E2E tests
  if [[ -f "$TESTS_DIR/e2e/backup-restore.test.sh" ]]; then
    report_stack "e2e"
    source "$TESTS_DIR/e2e/backup-restore.test.sh"
    for func in $(declare -F | grep 'declare -f test_' | awk '{print $3}'); do
      local start end dur res
      start=$(date +%s%N)
      if res=$("$func" 2>&1); then
        end=$(date +%s%N); dur=$(echo "scale=1; ($end - $start) / 1000000000" | bc 2>/dev/null || echo "0")
        report_result "${func#test_}" "pass" "$dur"
      else
        end=$(date +%s%N); dur=$(echo "scale=1; ($end - $start) / 1000000000" | bc 2>/dev/null || echo "0")
        report_result "${func#test_}" "fail" "$dur" "$res"
      fi
    done
  fi
else
  run_stack_tests "$STACK"
fi

report_summary
exit $?
