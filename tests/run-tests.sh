#!/usr/bin/env bash

set -euo pipefail

# Load libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/assert.sh"
source "${SCRIPT_DIR}/lib/docker.sh"
source "${SCRIPT_DIR}/lib/report.sh"

# Default values
STACK_NAME=""
RUN_ALL=false
TEST_RESULTS=()

# Help message
usage() {
  echo "Usage: $0 [--stack <name>] [--all]"
  echo "  --stack <name>  Run tests for a specific stack"
  echo "  --all          Run all tests"
  echo "  -h, --help     Show this help message"
  exit 1
}

# Parse arguments
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
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Print header
print_header() {
  echo "╔══════════════════════════════════════╗"
  echo "║   HomeLab Stack — Integration Tests  ║"
  echo "╚══════════════════════════════════════╝"
  echo
}

# Run a single test file
run_test_file() {
  local test_file="$1"
  local stack_name="$(basename "${test_file%.test.sh}")"
  
  if [[ "$RUN_ALL" = true ]] || [[ "$STACK_NAME" = "$stack_name" ]] || [[ -z "$STACK_NAME" && "$stack_name" = "base" ]]; then
    echo "[${stack_name}] Running tests from ${test_file}"
    # Source the test file to run its functions
    source "$test_file"
    # Run all functions starting with test_
    declare -F | grep -E "test_[a-zA-Z0-9_]+" | cut -d' ' -f3 | while read func; do
      echo "[${stack_name}] ▶ ${func}"
      start_time=$(date +%s)
      if $func; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        echo "[${stack_name}] ▶ ${func} ✅ PASS (${duration}s)"
      else
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        echo "[${stack_name}] ▶ ${func} ❌ FAIL (${duration}s)"
      fi
    done
  fi
}

# Main execution
main() {
  print_header
  
  # Run specific stack tests
  if [[ -n "$STACK_NAME" ]] && [[ "$RUN_ALL" = false ]]; then
    local test_file="${SCRIPT_DIR}/stacks/${STACK_NAME}.test.sh"
    if [[ -f "$test_file" ]]; then
      run_test_file "$test_file"
    else
      echo "Error: Test file not found for stack '${STACK_NAME}'"
      exit 1
    fi
  elif [[ "$RUN_ALL" = true ]]; then
    # Run all stack tests
    for test_file in "${SCRIPT_DIR}"/stacks/*.test.sh; do
      [[ -f "$test_file" ]] && run_test_file "$test_file"
    done
    
    # Run E2E tests
    for test_file in "${SCRIPT_DIR}"/e2e/*.test.sh; do
      [[ -f "$test_file" ]] && run_test_file "$test_file"
    done
  else
    # Run base tests by default
    run_test_file "${SCRIPT_DIR}/stacks/base.test.sh"
  fi
}

main "$@"