#!/usr/bin/env bash
# =============================================================================
# run-tests.sh — HomeLab Stack integration test runner
# Usage: ./tests/run-tests.sh [--stack <name>|--all] [--verbose]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

STACK="all"
VERBOSE=false
PASS=0
FAIL=0
SKIP=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --stack) STACK=$2; shift 2 ;;
    --all) STACK="all"; shift ;;
    --verbose) VERBOSE=true; shift ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

run_test_file() {
  local file=$1
  local name=$(basename "$file" .sh)
  echo ""
  echo "▶ Testing: $name"
  if bash "$file"; then
    echo "  ✅ $name PASSED"
  else
    echo "  ❌ $name FAILED"
  fi
}

echo "======================================"
echo "  HomeLab Stack Integration Tests"
echo "  Stack: $STACK | $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================"

if [[ "$STACK" == "all" ]]; then
  for f in "$SCRIPT_DIR/stacks/"*.sh; do
    [[ -f "$f" ]] && run_test_file "$f"
  done
else
  f="$SCRIPT_DIR/stacks/${STACK}.sh"
  [[ -f "$f" ]] && run_test_file "$f" || echo "No tests for: $STACK"
fi

echo ""
echo "======================================"
echo "  Results: ✅ $PASS passed  ❌ $FAIL failed  ⏭ $SKIP skipped"
echo "======================================"
[[ $FAIL -eq 0 ]] || exit 1
