#!/usr/bin/env bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0
TOTAL=0

# Load libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/assert.sh"
source "${SCRIPT_DIR}/lib/docker.sh"
source "${SCRIPT_DIR}/lib/report.sh"

# Default values
STACK=""
ALL=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --stack)
      STACK="$2"
      shift 2
      ;;
    --all)
      ALL=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--stack <name>] [--all] [-v|--verbose]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Print header
print_header() {
  echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   HomeLab Stack — Integration Tests  ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
  echo
}

# Run a single test function
run_test() {
  local test_func="$1"
  local test_name="$2"
  local stack_name="$3"
  
  TOTAL=$((TOTAL + 1))
  
  if [[ $VERBOSE == true ]]; then
    echo -n "[$stack_name] ▶ $test_name ... "
  fi
  
  local start_time=$(date +%s.%N)
  local result="PASS"
  local output=""
  
  # Capture output if not verbose
  if [[ $VERBOSE == false ]]; then
    output=$(eval "$test_func" 2>&1) || result="FAIL"
  else
    eval "$test_func" || result="FAIL"
  fi
  
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc)
  
  if [[ $result == "PASS" ]]; then
    PASSED=$((PASSED + 1))
    if [[ $VERBOSE == true ]]; then
      echo -e "${GREEN}✅ PASS${NC} (${duration}s)"
    fi
  else
    FAILED=$((FAILED + 1))
    if [[ $VERBOSE == true ]]; then
      echo -e "${RED}❌ FAIL${NC} (${duration}s)"
      echo "$output"
    else
      echo "[$stack_name] ▶ $test_name ... ${RED}❌ FAIL${NC} (${duration}s)"
      echo "$output"
    fi
  fi
}

# Run tests for a stack
run_stack_tests() {
  local stack_file="$1"
  local stack_name="$2"
  
  if [[ -f "$stack_file" ]]; then
    # Source the test file to load functions
    source "$stack_file"
    
    # Find all test functions
    declare -F | grep "test_" | while read -r line; do
      func_name=$(echo "$line" | awk '{print $3}')
      test_name=$(echo "$func_name" | sed 's/^test_//' | sed 's/_/ /g')
      run_test "$func_name" "$test_name" "$stack_name"
    done
  else
    echo "Warning: Test file $stack_file not found"
  fi
}

# Main execution
print_header

if [[ $ALL == true ]]; then
  for test_file in "${SCRIPT_DIR}/stacks/"*.test.sh; do
    stack_name=$(basename "$test_file" .test.sh)
    run_stack_tests "$test_file" "$stack_name"
  done
elif [[ -n "$STACK" ]]; then
  test_file="${SCRIPT_DIR}/stacks/${STACK}.test.sh"
  run_stack_tests "$test_file" "$STACK"
else
  echo "Error: Either --stack <name> or --all must be specified"
  exit 1
fi

# Print summary
echo
echo "=== SUMMARY ==="
echo "Total: $TOTAL | Passed: $PASSED | Failed: $FAILED"
if [[ $FAILED -gt 0 ]]; then
  exit 1
fi