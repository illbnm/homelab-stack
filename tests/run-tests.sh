#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_OUTPUT=false
STACK_FILTER=""
REPORT_FILE="${SCRIPT_DIR}/results/report.json"

source "${SCRIPT_DIR}/lib/assert.sh"
source "${SCRIPT_DIR}/lib/report.sh"
source "${SCRIPT_DIR}/lib/docker.sh"

print_help() {
  cat <<EOF
Usage: ./run-tests.sh [options]

Options:
  --stack <name>    Run tests for a specific stack only
  --all             Run all stack tests
  --json            Enable JSON output to tests/results/report.json
  --help            Show this help message

Stacks:
  base, media, storage, monitoring, network, productivity, ai, sso, databases, notifications

Examples:
  ./run-tests.sh --stack base
  ./run-tests.sh --all --json
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) STACK_FILTER="$2"; shift 2 ;;
    --all) STACK_FILTER="all"; shift ;;
    --json) JSON_OUTPUT=true; shift ;;
    --help) print_help; exit 0 ;;
    *) echo "Unknown option: $1"; print_help; exit 1 ;;
  esac
done

if [ "$JSON_OUTPUT" = true ]; then
  export REPORT_FILE
  report_init
fi

print_banner

run_stack_tests() {
  local stack="$1"
  local test_file="${SCRIPT_DIR}/stacks/${stack}.test.sh"

  if [ ! -f "$test_file" ]; then
    echo "No test file found for stack: $stack"
    return
  fi

  bash "$test_file"
}

run_all_stacks() {
  local stacks=("base" "media" "storage" "monitoring" "network" "productivity" "ai" "sso" "databases" "notifications")
  for stack in "${stacks[@]}"; do
    run_stack_tests "$stack"
  done
}

if [ "$STACK_FILTER" = "all" ] || [ -z "$STACK_FILTER" ]; then
  run_all_stacks
elif [ -n "$STACK_FILTER" ]; then
  run_stack_tests "$STACK_FILTER"
fi

print_summary
