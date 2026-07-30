#!/usr/bin/env bash
set -euo pipefail

# ════════════════════════════════════════════════════════════════
# Test Runner — Integration Testing Suite
# ════════════════════════════════════════════════════════════════
# Usage:
#   ./tests/run-tests.sh                    # Run all tests
#   ./tests/run-tests.sh --stack base       # Run specific stack tests
#   ./tests/run-tests.sh --all              # Run everything including E2E
#   ./tests/run-tests.sh --stack sso --e2e  # Stack + E2E tests
#   ./tests/run-tests.sh --json              # Output as JSON
# ════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/assert.sh"
source "${SCRIPT_DIR}/lib/docker.sh"
source "${SCRIPT_DIR}/lib/report.sh"

STACK=""
RUN_ALL=false
RUN_E2E=false
JSON_OUTPUT=false
VERBOSE=false

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) STACK="$2"; shift 2 ;;
    --all)   RUN_ALL=true; shift ;;
    --e2e)   RUN_E2E=true; shift ;;
    --json)  JSON_OUTPUT=true; shift ;;
    --verbose|-v) VERBOSE=true; shift ;;
    --help|-h)
      echo "Usage: run-tests.sh [--stack <name>] [--all] [--e2e] [--json] [-v]"
      echo ""
      echo "Options:"
      echo "  --stack <name>  Run tests for a specific stack"
      echo "  --all           Run all stack tests"
      echo "  --e2e           Include end-to-end tests"
      echo "  --json          Output results as JSON"
      echo "  -v, --verbose   Verbose output"
      echo ""
      echo "Available stacks: base, media, storage, monitoring, network,"
      echo "  productivity, ai, sso, databases, notifications"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Initialize report ──────────────────────────────────────────
report_init "$JSON_OUTPUT"

# ── Stack test files ───────────────────────────────────────────
STACK_DIR="${SCRIPT_DIR}/stacks"
E2E_DIR="${SCRIPT_DIR}/e2e"
ALL_STACKS=("base" "media" "storage" "monitoring" "network" "productivity" "ai" "sso" "databases" "notifications")

run_stack_tests() {
  local stack_name="$1"
  local test_file="${STACK_DIR}/${stack_name}.test.sh"

  if [[ ! -f "$test_file" ]]; then
    report_skip "$stack_name" "Test file not found: ${test_file}"
    return 0
  fi

  report_section "$stack_name"
  # Source and run the test file
  # shellcheck disable=SC1090
  source "$test_file"

  # Find and run all test_* functions
  local tests
  tests=$(declare -F | awk '{print $3}' | grep "^test_" | sort)
  if [[ -z "$tests" ]]; then
    report_skip "$stack_name" "No test functions found"
    return 0
  fi

  for test_fn in $tests; do
    if $VERBOSE; then
      echo "  Running: ${test_fn}"
    fi
    report_test_start "$test_fn"
    if "$test_fn" 2>/dev/null; then
      report_test_pass "$test_fn"
    else
      report_test_fail "$test_fn" "Test returned non-zero"
    fi
    report_test_end "$test_fn"
    # Unset to avoid re-running in next stack
    unset -f "$test_fn"
  done
}

run_e2e_tests() {
  if [[ ! -d "$E2E_DIR" ]]; then
    report_skip "e2e" "E2E directory not found"
    return 0
  fi

  for e2e_file in "${E2E_DIR}"/*.test.sh; do
    [[ -f "$e2e_file" ]] || continue
    local e2e_name
    e2e_name=$(basename "$e2e_file" .test.sh)
    report_section "e2e:${e2e_name}"
    # shellcheck disable=SC1090
    source "$e2e_file"
    local tests
    tests=$(declare -F | awk '{print $3}' | grep "^test_" | sort)
    for test_fn in $tests; do
      report_test_start "$test_fn"
      if "$test_fn" 2>/dev/null; then
        report_test_pass "$test_fn"
      else
        report_test_fail "$test_fn" "E2E test returned non-zero"
      fi
      report_test_end "$test_fn"
      unset -f "$test_fn"
    done
  done
}

# ── Run tests ──────────────────────────────────────────────────
if [[ -n "$STACK" ]]; then
  run_stack_tests "$STACK"
elif $RUN_ALL; then
  for s in "${ALL_STACKS[@]}"; do
    run_stack_tests "$s"
  done
else
  echo "No stack specified. Use --stack <name> or --all"
  exit 1
fi

if $RUN_E2E || $RUN_ALL; then
  run_e2e_tests
fi

# ── Summary ────────────────────────────────────────────────────
report_summary