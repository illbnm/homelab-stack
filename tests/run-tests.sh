#!/usr/bin/env bash
# run-tests.sh — HomeLab Stack Test Runner
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="all"; STACK_FILTER=""; JSON_OUTPUT=false; VERBOSE=false; TIMEOUT=60

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Run HomeLab Stack integration tests.

Options:
  --all                 Run all stack tests (default)
  --stack <name>        Run tests for a specific stack
  --json                Enable JSON report output
  --verbose             Show detailed command output
  --timeout <seconds>   Per-test timeout (default: 60)
  --list                List available stacks
  --help                Show this help

Available stacks:
  base, media, monitoring, sso, network, databases, storage,
  productivity, ai, notifications, dashboard, home-automation

Examples:
  $(basename "$0") --all
  $(basename "$0") --stack base --json
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)     MODE="all"; shift ;;
    --stack)   MODE="stack"; STACK_FILTER="${2:-}"; shift 2 ;;
    --json)    JSON_OUTPUT=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    --timeout) TIMEOUT="${2:-60}"; shift 2 ;;
    --list)    for f in "$SCRIPT_DIR"/stacks/*.test.sh; do basename "$f" .test.sh | sed 's/^/  /'; done; exit 0 ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Source libraries
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"

cd "$PROJECT_ROOT"
export RESULTS_DIR="$SCRIPT_DIR/results"
export TEST_TIMEOUT="$TIMEOUT"

print_header

run_test_file() {
  local test_file="$1" stack_name
  stack_name=$(basename "$test_file" .test.sh)
  export STACK_NAME="$stack_name"

  if [[ ! -f "$test_file" ]]; then
    echo "  [${stack_name}] \033[33m\u23ed SKIP\033[0m — test file not found"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1)); return 0
  fi

  echo "── $stack_name ──────────────────────────────────"

  # Source the file and run each test_ function
  source "$test_file"
  local test_fns
  test_fns=$(declare -F | awk '/^declare -f test_/ {print $3}')
  for fn in $test_fns; do
    if [[ "$VERBOSE" == true ]]; then
      timeout "$TEST_TIMEOUT" bash -c "source '$SCRIPT_DIR/lib/assert.sh'; source '$test_file'; $fn" 2>&1 || true
    else
      timeout "$TEST_TIMEOUT" bash -c "source '$SCRIPT_DIR/lib/assert.sh'; source '$test_file'; $fn" >/dev/null 2>&1 || true
    fi
  done
}

if [[ "$MODE" == "stack" ]]; then
  run_test_file "$SCRIPT_DIR/stacks/${STACK_FILTER}.test.sh"
elif [[ "$MODE" == "all" ]]; then
  for test_file in "$SCRIPT_DIR"/stacks/*.test.sh; do
    [[ -f "$test_file" ]] || continue
    run_test_file "$test_file"
  done
  for test_file in "$SCRIPT_DIR"/e2e/*.test.sh; do
    [[ -f "$test_file" ]] || continue
    run_test_file "$test_file"
  done
fi

print_summary
[[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
