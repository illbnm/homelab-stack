#!/usr/bin/env bash
set -euo pipefail

TEST_LIB_DIR="$(cd "$(dirname "$0")/lib" && pwd)"
TEST_STACKS_DIR="$(cd "$(dirname "$0")/stacks" && pwd)"
TEST_E2E_DIR="$(cd "$(dirname "$0")/e2e" && pwd)"
RESULTS_DIR="$(cd "$(dirname "$0")" && pwd)/results"

source "$TEST_LIB_DIR/assert.sh"
source "$TEST_LIB_DIR/docker.sh"
source "$TEST_LIB_DIR/report.sh"

ASSERT_START_TIME=${SECONDS}

AVAILABLE_STACKS=()
for f in "$TEST_STACKS_DIR"/*.test.sh; do
    [[ -f "$f" ]] && AVAILABLE_STACKS+=("$(basename "$f" .test.sh)")
done

usage() {
    cat <<EOF
HomeLab Stack — Integration Tests

Usage: $(basename "$0") [OPTIONS]

Options:
  --stack <name>   Run tests for a specific stack only
  --all            Run all available stack tests
  --e2e            Include end-to-end tests
  --json           Output JSON report to tests/results/report.json
  --help           Show this help message

Available stacks:
$(printf '  %s\n' "${AVAILABLE_STACKS[@]:-none}")

Examples:
  $(basename "$0") --stack base
  $(basename "$0") --all
  $(basename "$0") --all --e2e --json
EOF
    exit "${1:-0}"
}

RUN_STACK=""
RUN_ALL=false
RUN_E2E=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stack)  RUN_STACK="$2"; shift 2 ;;
        --all)    RUN_ALL=true; shift ;;
        --e2e)    RUN_E2E=true; shift ;;
        --json)   JSON_OUTPUT=true; shift ;;
        --help)   usage 0 ;;
        *)        echo "Unknown option: $1"; usage 1 ;;
    esac
done

if [[ -z "$RUN_STACK" && "$RUN_ALL" == "false" ]]; then
    echo "ERROR: Specify --stack <name> or --all"
    usage 1
fi

echo "╔══════════════════════════════════════╗"
echo "║  HomeLab Stack — Integration Tests   ║"
echo "╚══════════════════════════════════════╝"

report_init

run_stack_tests() {
    local stack="$1"
    local test_file="$TEST_STACKS_DIR/${stack}.test.sh"
    if [[ ! -f "$test_file" ]]; then
        echo "WARN: No test file for stack '$stack' at $test_file"
        return
    fi
    source "$test_file"
}

if [[ -n "$RUN_STACK" ]]; then
    run_stack_tests "$RUN_STACK"
fi

if [[ "$RUN_ALL" == "true" ]]; then
    for stack in "${AVAILABLE_STACKS[@]}"; do
        run_stack_tests "$stack"
    done
fi

if [[ "$RUN_E2E" == "true" ]]; then
    for f in "$TEST_E2E_DIR"/*.test.sh; do
        [[ -f "$f" ]] && source "$f"
    done
fi

report_print_summary

if [[ "$JSON_OUTPUT" == "true" ]]; then
    report_write_json
    echo "JSON report written to $REPORT_JSON"
fi

if [[ $ASSERT_FAIL -gt 0 ]]; then
    exit 1
fi