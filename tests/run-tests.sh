#!/usr/bin/env bash

# HomeLab Stack Integration Tests Runner
# Usage: ./run-tests.sh [--stack <name>] [--all] [--ci]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
STACKS_DIR="${SCRIPT_DIR}/stacks"
E2E_DIR="${SCRIPT_DIR}/e2e"

# Source libraries
source "${LIB_DIR}/assert.sh"
source "${LIB_DIR}/docker.sh"
source "${LIB_DIR}/report.sh"

# Default values
STACK_NAME=""
RUN_ALL=false
CI_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --stack)
      STACK_NAME="$2"
      shift 2
      ;;
    --all)
      RUN_ALL=true
      shift
      ;;
    --ci)
      CI_MODE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Print banner
print_banner() {
  echo "╔══════════════════════════════════════╗"
  echo "║   HomeLab Stack — Integration Tests  ║"
  echo "╚══════════════════════════════════════╝"
  echo
}

# Run a single test file
run_test_file() {
  local test_file=$1
  local stack_name=$(basename "${test_file}" .test.sh)
  
  if [[ -f "$test_file" ]]; then
    echo "Running tests for stack: ${stack_name}"
    # Source the test file to run its functions
    source "$test_file"
    
    # Find all functions starting with 'test_'
    declare -F | awk '{print $3}' | grep "^test_" | while read -r func; do
      if declare -F "$func" > /dev/null; then
        echo -n "[$stack_name] ▶ ${func#test_} ... "
        start_time=$(date +%s)
        
        # Run the test function
        if "$func" > /tmp/test_output.log 2>&1; then
          end_time=$(date +%s)
          duration=$((end_time - start_time))
          echo "✅ PASS (${duration}s)"
        else
          end_time=$(date +%s)
          duration=$((end_time - start_time))
          echo "❌ FAIL (${duration}s)"
          echo "  Output: $(cat /tmp/test_output.log)"
        fi
      fi
    done
  fi
}

# Main execution
print_banner

if [[ "$RUN_ALL" == true ]]; then
  # Run all stack tests
  for test_file in "${STACKS_DIR}"/*.test.sh; do
    run_test_file "$test_file"
  done
  
  # Run E2E tests
  for e2e_file in "${E2E_DIR}"/*.test.sh; do
    run_test_file "$e2e_file"
  done
elif [[ -n "$STACK_NAME" ]]; then
  # Run specific stack tests
  test_file="${STACKS_DIR}/${STACK_NAME}.test.sh"
  run_test_file "$test_file"
else
  echo "Please specify --stack <name> or --all"
  exit 1
fi