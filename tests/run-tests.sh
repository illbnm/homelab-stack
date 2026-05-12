#!/usr/bin/env bash
# run-tests.sh — HomeLab Stack Integration Test Runner
# Usage: ./run-tests.sh [--stack <name>|--all] [--json] [--help]
set -euo pipefail

START=$(date +%s)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
ALL=false; JSON=false; STACK=""

cd "$SCRIPT_DIR"

source lib/report.sh
source lib/assert.sh

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) STACK="$2"; shift 2 ;;
    --all) ALL=true; shift ;;
    --json) JSON=true; shift ;;
    --help) echo "Usage: $0 [--stack <name>|--all] [--json]"; echo "Stacks: base media storage monitoring network productivity ai sso databases notifications"; exit 0 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

init_report
print_banner

run_suite() {
  local name="$1"
  local file="$SCRIPT_DIR/stacks/${name}.test.sh"
  if [ ! -f "$file" ]; then echo -e "\n[${name}] ⏭ no test file"; return; fi
  echo -e "\n\033[36m[${name}]\033[0m"
  local s=$SECONDS
  PASS=0; FAIL=0; SKIP=0; TOTAL=0
  source "$file"
  local d=$((SECONDS - s))
  [ "$JSON" = true ] && write_report "$name" "$PASS" "$FAIL" "$SKIP" "$d"
}

STACKS="base media storage monitoring network productivity ai sso databases notifications"

if [ -n "$STACK" ]; then
  run_suite "$STACK"
elif [ "$ALL" = true ]; then
  for s in $STACKS; do run_suite "$s"; done
else
  echo "Specify --stack <name> or --all"; exit 1
fi

finalize_report
print_summary
