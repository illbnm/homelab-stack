#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
FAILED_SUITES=()

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --stack          Run stack tests only"
    echo "  --all            Run all tests (default)"
    echo "  --verbose, -v    Verbose output"
    echo "  --help, -h       Show this help message"
    echo ""
    echo "Test Suites:"
    echo "  - Stack operations (push, pop, peek, size, etc.)"
    echo "  - Error handling"
    echo "  - Edge cases"
    echo "  - Performance tests"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

run_test_suite() {
    local suite_name="$1"
    local test_script="$2"
    
    log_info "Running $suite_name tests..."
    
    if [ ! -f "$test_script" ]; then
        log_error "Test script not found: $test_script"
        FAILED_SUITES+=("$suite_name")
        return 1
    fi
    
    if ! chmod +x "$test_script"; then
        log_error "Failed to make test script executable: $test_script"
        FAILED_SUITES+=("$suite_name")
        return 1
    fi
    
    local suite_output
    local suite_exit_code
    
    if [ "$VERBOSE" = "true" ]; then
        "$test_script"
        suite_exit_code=$?
    else
        suite_output=$("$test_script" 2>&1)
        suite_exit_code=$?
    fi
    
    if [ $suite_exit_code -eq 0 ]; then
        log_success "$suite_name tests passed"
        if [ "$VERBOSE" = "false" ] && [[ "$suite_output" =~ Tests\ passed:\ ([0-9]+) ]]; then
            local tests_passed="${BASH_REMATCH[1]}"
            PASSED_TESTS=$((PASSED_TESTS + tests_passed))
            TOTAL_TESTS=$((TOTAL_TESTS + tests_passed))
        fi
        return 0
    else
        log_error "$suite_name tests failed"
        FAILED_SUITES+=("$suite_name")
        if [ "$VERBOSE" = "false" ]; then
            echo "$suite_output"
        fi
        if [[ "$suite_output" =~ Tests\ failed:\ ([0-9]+) ]]; then
            local tests_failed="${BASH_REMATCH[1]}"
            FAILED_TESTS=$((FAILED_TESTS + tests_failed))
            TOTAL_TESTS=$((TOTAL_TESTS + tests_failed))
        fi
        if [[ "$suite_output" =~ Tests\ passed:\ ([0-9]+) ]]; then
            local tests_passed="${BASH_REMATCH[1]}"
            PASSED_TESTS=$((PASSED_TESTS + tests_passed))
            TOTAL_TESTS=$((TOTAL_TESTS + tests_passed))
        fi
        return 1
    fi
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    # Check if Node.js is available
    if ! command -v node &> /dev/null; then
        log_error "Node.js is required but not installed"
        return 1
    fi
    
    # Check if npm is available
    if ! command -v npm &> /dev/null; then
        log_error "npm is required but not installed"
        return 1
    fi
    
    # Check if package.json exists
    if [ ! -f "$PROJECT_ROOT/package.json" ]; then
        log_error "package.json not found in project root"
        return 1
    fi
    
    # Install dependencies if node_modules doesn't exist
    if [ ! -d "$PROJECT_ROOT/node_modules" ]; then
        log_info "Installing dependencies..."
        cd "$PROJECT_ROOT"
        npm install
        if [ $? -ne 0 ]; then
            log_error "Failed to install dependencies"
            return 1
        fi
    fi
    
    log_success "Dependencies check passed"
    return 0
}

run_stack_tests() {
    local stack_test_dir="$SCRIPT_DIR/stack"
    local all_passed=true
    
    log_info "=== Stack Test Suite ==="
    
    # Run basic operations tests
    if ! run_test_suite "Stack Basic Operations" "$stack_test_dir/test-basic-ops.sh"; then
        all_passed=false
    fi
    
    # Run error handling tests
    if ! run_test_suite "Stack Error Handling" "$stack_test_dir/test-error-handling.sh"; then
        all_passed=false
    fi
    
    # Run edge cases tests
    if ! run_test_suite "Stack Edge Cases" "$stack_test_dir/test-edge-cases.sh"; then
        all_passed=false
    fi
    
    # Run performance tests
    if ! run_test_suite "Stack Performance" "$stack_test_dir/test-performance.sh"; then
        all_passed=false
    fi
    
    if [ "$all_passed" = "true" ]; then
        log_success "All stack tests passed"
        return 0
    else
        log_error "Some stack tests failed"
        return 1
    fi
}

run_all_tests() {
    log_info "=== Running All Test Suites ==="
    
    local all_passed=true
    
    # Run stack tests
    if ! run_stack_tests; then
        all_passed=false
    fi
    
    # Add other test suites here as they are implemented
    # if ! run_queue_tests; then
    #     all_passed=false
    # fi
    
    if [ "$all_passed" = "true" ]; then
        log_success "All test suites passed"
        return 0
    else
        log_error "Some test suites failed"
        return 1
    fi
}

print_summary() {
    echo ""
    echo "=== Test Summary ==="
    echo "Total tests: $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
    
    if [ ${#FAILED_SUITES[@]} -gt 0 ]; then
        echo ""
        echo "Failed test suites:"
        for suite in "${FAILED_SUITES[@]}"; do
            echo -e "  ${RED}✗${NC} $suite"
        done
    fi
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo ""
        log_success "All tests passed! 🎉"
        return 0
    else
        echo ""
        log_error "Some tests failed! ❌"
        return 1
    fi
}

main() {
    local run_stack=false
    local run_all=true
    VERBOSE=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --stack)
                run_stack=true
                run_all=false
                shift
                ;;
            --all)
                run_all=true
                run_stack=false
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Check dependencies first
    if ! check_dependencies; then
        exit 1
    fi
    
    local start_time=$(date +%s)
    local test_result=0
    
    echo "=== Automated Test Suite ==="
    echo "Project: Stack Data Structure Implementation"
    echo "Timestamp: $(date)"
    echo ""
    
    # Run selected tests
    if [ "$run_stack" = "true" ]; then
        if ! run_stack_tests; then
            test_result=1
        fi
    elif [ "$run_all" = "true" ]; then
        if ! run_all_tests; then
            test_result=1
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo "Test execution completed in ${duration}s"
    
    print_summary
    
    exit $test_result
}

# Run main function with all arguments
main "$@"