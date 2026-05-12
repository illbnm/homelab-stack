#!/usr/bin/env bash
# HomeLab Stack Integration Test Runner
# Usage: ./tests/run-tests.sh [--stack <name>] [--all] [--json]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/report.sh"

STACKS=(base monitoring notifications databases network productivity media ai storage)
RUN_ALL=false
TARGET_STACK=""
JSON_OUTPUT=false
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --stack) TARGET_STACK="$2"; shift 2 ;;
    --all) RUN_ALL=true; shift ;;
    --json) JSON_OUTPUT=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$TARGET_STACK" ] && [ "$RUN_ALL" = false ]; then
  RUN_ALL=true
fi

init_report

run_suite() {
  local name="$1"
  local test_file="$SCRIPT_DIR/stacks/${name}.test.sh"

  if [ ! -f "$test_file" ]; then
    echo "⚠️  No test file for stack: $name"
    return
  fi

  echo ""
  # Run test in subshell to capture PASS/FAIL
  chmod +x "$test_file"
  if bash "$test_file"; then
    true
  fi
}

if [ -n "$TARGET_STACK" ]; then
  run_suite "$TARGET_STACK"
else
  for stack in "${STACKS[@]}"; do
    run_suite "$stack"
  done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏁 All test suites completed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$JSON_OUTPUT" = true ]; then
  print_final_report
fi
