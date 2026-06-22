#!/usr/bin/env bash

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

source "$SCRIPT_DIR/lib/report.sh"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"

usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  --stack <name>   Run tests for a specific stack"
  echo "  --all            Run all tests"
  echo "  --help           Show this help message"
  exit 0
}

TARGET_STACK=""
RUN_ALL=0

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --stack) TARGET_STACK="$2"; shift ;;
    --all) RUN_ALL=1 ;;
    --help) usage ;;
    *) echo "Unknown parameter passed: $1"; usage ;;
  esac
  shift
done

if [ -z "$TARGET_STACK" ] && [ "$RUN_ALL" -eq 0 ]; then
  echo "Error: Must specify --stack <name> or --all"
  usage
fi

get_time() {
  python3 -c 'import time; print(time.time())' 2>/dev/null || date +%s
}

report_start

run_test_file() {
  local file="$1"
  local stack_name
  stack_name=$(basename "$file" .test.sh)
  
  # Source in a subshell is hard to extract functions, so we parse it
  local test_funcs
  test_funcs=$(grep -E '^test_[a-zA-Z0-9_]+\(\)' "$file" | sed 's/()//')
  
  for func in $test_funcs; do
    local start_time
    start_time=$(get_time)
    
    local error_msg
    if error_msg=$(bash -c "source '$SCRIPT_DIR/lib/assert.sh'; source '$file'; $func" 2>&1); then
      local end_time
      end_time=$(get_time)
      local duration
      duration=$(awk -v t1="$start_time" -v t2="$end_time" 'BEGIN{printf "%.1f", t2-t1}')
      report_pass "$stack_name" "${func#test_}" "$duration"
    else
      local end_time
      end_time=$(get_time)
      local duration
      duration=$(awk -v t1="$start_time" -v t2="$end_time" 'BEGIN{printf "%.1f", t2-t1}')
      report_fail "$stack_name" "${func#test_}" "$duration" "$error_msg"
    fi
  done
}

if [ "$RUN_ALL" -eq 1 ]; then
  for f in "$SCRIPT_DIR"/stacks/*.test.sh "$SCRIPT_DIR"/e2e/*.test.sh; do
    [ -e "$f" ] && run_test_file "$f"
  done
else
  f="$SCRIPT_DIR/stacks/${TARGET_STACK}.test.sh"
  if [ -f "$f" ]; then
    run_test_file "$f"
  else
    echo "Error: test file $f not found"
    exit 1
  fi
fi

report_summary
