#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Source libraries
source lib/assert.sh
source lib/docker.sh
source lib/report.sh

# Global counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Parse arguments
STACK_FILTER=""
RUN_ALL=false
RUN_E2E=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)
      STACK_FILTER="$2"
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
    --help|-h)
      echo "Usage: $0 [--stack <name>] [--all] [--e2e]"
      echo ""
      echo "Options:"
      echo "  --stack <name>  Run tests for a specific stack"
      echo "  --all           Run all stack tests"
      echo "  --e2e           Run end-to-end tests"
      echo "  --help, -h      Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Initialize report
report_init

# Print header
print_header

# Track test execution time
OVERALL_START=$(date +%s)

# Run a single test file
run_test_file() {
  local file="$1"
  local stack_name="$2"
  
  # Source the test file
  source "$file"
  
  # Find and run all test functions
  local tests
  tests=$(grep -E '^test_[a-zA-Z0-9_]+\(\)' "$file" | sed 's/().*//')
  
  while IFS= read -r test_func; do
    [[ -z "$test_func" ]] && continue
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    local test_start=$(date +%s)
    local test_status="PASS"
    local test_error=""
    
    # Run the test
    set +e
    test_output=$($test_func 2>&1)
    local exit_code=$?
    set -e
    
    local test_end=$(date +%s)
    local duration=$((test_end - test_start))
    
    if [[ $exit_code -eq 0 ]]; then
      PASSED_TESTS=$((PASSED_TESTS + 1))
    elif [[ $exit_code -eq 2 ]]; then
      SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
      test_status="SKIP"
    else
      FAILED_TESTS=$((FAILED_TESTS + 1))
      test_status="FAIL"
      test_error="$test_output"
    fi
    
    print_test_result "$stack_name" "$test_func" "$test_status" "$duration" "$test_error"
    
  done <<< "$tests"
}

# Run stack tests
if [[ "$RUN_ALL" == true ]] || [[ -n "$STACK_FILTER" ]]; then
  for test_file in stacks/*.test.sh; do
    [[ -f "$test_file" ]] || continue
    
    local stack_name
    stack_name=$(basename "$test_file" .test.sh)
    
    # Filter if specific stack requested
    if [[ -n "$STACK_FILTER" ]] && [[ "$stack_name" != "$STACK_FILTER" ]]; then
      continue
    fi
    
    run_test_file "$test_file" "$stack_name"
  done
fi

# Run E2E tests
if [[ "$RUN_E2E" == true ]] || [[ "$RUN_ALL" == true ]]; then
  for e2e_file in e2e/*.test.sh; do
    [[ -f "$e2e_file" ]] || continue
    
    local e2e_name
    e2e_name=$(basename "$e2e_file" .test.sh)
    
    run_test_file "$e2e_file" "e2e/$e2e_name"
  done
fi

OVERALL_END=$(date +%s)
TOTAL_DURATION=$((OVERALL_END - OVERALL_START))

# Print summary
print_summary "$TOTAL_TESTS" "$PASSED_TESTS" "$FAILED_TESTS" "$SKIPPED_TESTS" "$TOTAL_DURATION"

# Generate JSON report
generate_json_report "$TOTAL_TESTS" "$PASSED_TESTS" "$FAILED_TESTS" "$SKIPPED_TESTS" "$TOTAL_DURATION"

# Exit with failure if any tests failed
[[ $FAILED_TESTS -eq 0 ]] || exit 1