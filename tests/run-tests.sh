#!/bin/bash

# HomeLab Stack Integration Test Runner

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
TARGET_STACK=""
RUN_ALL=false
RUN_E2E=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --stack)
      TARGET_STACK="$2"
      shift 2
      ;;
    --all)
      RUN_ALL=true
      shift
      ;;
    --e2e)
      RUN_E2E=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --stack <name>  Run tests for a specific stack"
      echo "  --all           Run all stack tests"
      echo "  --e2e           Run end-to-end tests"
      echo "  --help          Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Print banner
print_test_banner() {
  echo "╔══════════════════════════════════════╗"
  echo "║   HomeLab Stack — Integration Tests  ║"
  echo "╚══════════════════════════════════════╝"
  echo
}

# Run a single test file
run_test_file() {
  local test_file=$1
  local stack_name=$(basename "${test_file}" .test.sh)
  
  echo "[${stack_name}] Running tests from ${test_file}"
  
  # Source the test file to load its functions
  source "${test_file}"
  
  # Find all functions starting with 'test_'
  declare -F | awk '{print $3}' | grep "^test_" | while read -r test_func; do
    if [[ "${test_func}" == test_* ]]; then
      local start_time=$(date +%s)
      local test_name=$(echo "${test_func}" | sed 's/^test_//' | sed 's/_/ /g')
      
      # Run the test function
      if ${test_func}; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo "[${stack_name}] ▶ ${test_name} ✅ PASS (${duration}s)"
      else
        echo "[${stack_name}] ▶ ${test_name} ❌ FAIL"
        return 1
      fi
    fi
  done
}

# Main execution
print_test_banner

if [[ "${RUN_E2E}" == true ]]; then
  for test_file in "${E2E_DIR}"/*.test.sh; do
    [[ -f "${test_file}" ]] && run_test_file "${test_file}"
  done
elif [[ "${RUN_ALL}" == true ]]; then
  for test_file in "${STACKS_DIR}"/*.test.sh; do
    [[ -f "${test_file}" ]] && run_test_file "${test_file}"
  done
elif [[ -n "${TARGET_STACK}" ]]; then
  test_file="${STACKS_DIR}/${TARGET_STACK}.test.sh"
  if [[ -f "${test_file}" ]]; then
    run_test_file "${test_file}"
  else
    echo "Test file not found: ${test_file}"
    exit 1
  fi
else
  echo "No test target specified. Use --help for usage."
  exit 1
fi