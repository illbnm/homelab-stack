#!/bin/bash

# HomeLab Stack Test Runner
# Supports --stack <name> or --all flags with colored output and JSON reporting

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
STACKS_DIR="${SCRIPT_DIR}/stacks"
E2E_DIR="${SCRIPT_DIR}/e2e"

# Load libraries
source "${LIB_DIR}/assert.sh"
source "${LIB_DIR}/docker.sh"
source "${LIB_DIR}/report.sh"

# Test results
declare -A test_results
total_tests=0
passed_tests=0
failed_tests=0
start_time=$(date +%s)

# Available stacks
AVAILABLE_STACKS=(
    "base"
    "media"
    "storage"
    "monitoring"
    "network"
    "productivity"
    "ai"
    "sso"
    "databases"
    "notifications"
)

print_usage() {
    echo -e "${CYAN}HomeLab Stack Test Runner${NC}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --stack <name>    Run tests for a specific stack"
    echo "  --all            Run all available tests"
    echo "  --e2e            Run end-to-end tests only"
    echo "  --ci             Run in CI mode (no colors, JSON output)"
    echo "  --help           Show this help message"
    echo ""
    echo "Available stacks:"
    for stack in "${AVAILABLE_STACKS[@]}"; do
        echo "  - ${stack}"
    done
    echo ""
    echo "Examples:"
    echo "  $0 --stack media"
    echo "  $0 --all"
    echo "  $0 --e2e"
}

log_info() {
    if [[ "${CI_MODE:-false}" == "false" ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    if [[ "${CI_MODE:-false}" == "false" ]]; then
        echo -e "${GREEN}[PASS]${NC} $1"
    fi
}

log_warning() {
    if [[ "${CI_MODE:-false}" == "false" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $1"
    fi
}

log_error() {
    if [[ "${CI_MODE:-false}" == "false" ]]; then
        echo -e "${RED}[FAIL]${NC} $1"
    fi
}

run_test_file() {
    local test_file="$1"
    local stack_name="$2"

    if [[ ! -f "$test_file" ]]; then
        log_warning "Test file not found: $test_file"
        return 0
    fi

    log_info "Running tests for stack: ${stack_name}"

    # Make test file executable
    chmod +x "$test_file"

    # Source the test file and run tests
    if source "$test_file"; then
        log_success "Stack ${stack_name} tests completed"
        return 0
    else
        log_error "Stack ${stack_name} tests failed"
        return 1
    fi
}

run_stack_tests() {
    local stack="$1"
    local test_file="${STACKS_DIR}/${stack}.test.sh"

    if run_test_file "$test_file" "$stack"; then
        test_results["$stack"]="PASS"
        return 0
    else
        test_results["$stack"]="FAIL"
        return 1
    fi
}

run_e2e_tests() {
    log_info "Running end-to-end tests"
    local e2e_passed=0
    local e2e_total=0

    for test_file in "${E2E_DIR}"/*.test.sh; do
        if [[ -f "$test_file" ]]; then
            local test_name=$(basename "$test_file" .test.sh)
            ((e2e_total++))

            if run_test_file "$test_file" "e2e-${test_name}"; then
                test_results["e2e-${test_name}"]="PASS"
                ((e2e_passed++))
            else
                test_results["e2e-${test_name}"]="FAIL"
            fi
        fi
    done

    log_info "E2E tests: ${e2e_passed}/${e2e_total} passed"
    return $((e2e_total - e2e_passed))
}

validate_stack() {
    local stack="$1"
    for available in "${AVAILABLE_STACKS[@]}"; do
        if [[ "$stack" == "$available" ]]; then
            return 0
        fi
    done
    return 1
}

print_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [[ "${CI_MODE:-false}" == "false" ]]; then
        echo ""
        echo -e "${PURPLE}=================== TEST SUMMARY ===================${NC}"
        echo -e "${CYAN}Total Duration:${NC} ${duration}s"
        echo -e "${CYAN}Total Tests:${NC} ${total_tests}"
        echo -e "${GREEN}Passed:${NC} ${passed_tests}"
        echo -e "${RED}Failed:${NC} ${failed_tests}"
        echo ""

        for test_name in "${!test_results[@]}"; do
            local result="${test_results[$test_name]}"
            if [[ "$result" == "PASS" ]]; then
                echo -e "  ${GREEN}✓${NC} ${test_name}"
            else
                echo -e "  ${RED}✗${NC} ${test_name}"
            fi
        done
        echo -e "${PURPLE}==================================================${NC}"
    fi

    # Generate JSON report
    generate_json_report "$duration"
}

main() {
    local mode=""
    local target_stack=""

    if [[ $# -eq 0 ]]; then
        print_usage
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --stack)
                mode="single"
                target_stack="$2"
                shift 2
                ;;
            --all)
                mode="all"
                shift
                ;;
            --e2e)
                mode="e2e"
                shift
                ;;
            --ci)
                CI_MODE="true"
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option $1${NC}"
                print_usage
                exit 1
                ;;
        esac
    done

    # Initialize report
    init_report

    case "$mode" in
        "single")
            if ! validate_stack "$target_stack"; then
                log_error "Invalid stack: $target_stack"
                print_usage
                exit 1
            fi

            log_info "Starting tests for stack: $target_stack"
            total_tests=1

            if run_stack_tests "$target_stack"; then
                passed_tests=1
            else
                failed_tests=1
            fi
            ;;

        "all")
            log_info "Starting tests for all stacks"
            total_tests=${#AVAILABLE_STACKS[@]}

            for stack in "${AVAILABLE_STACKS[@]}"; do
                if run_stack_tests "$stack"; then
                    ((passed_tests++))
                else
                    ((failed_tests++))
                fi
            done
            ;;

        "e2e")
            run_e2e_tests
            total_tests=${#test_results[@]}

            for result in "${test_results[@]}"; do
                if [[ "$result" == "PASS" ]]; then
                    ((passed_tests++))
                else
                    ((failed_tests++))
                fi
            done
            ;;

        *)
            log_error "No valid mode specified"
            print_usage
            exit 1
            ;;
    esac

    print_summary

    # Exit with error code if any tests failed
    if [[ $failed_tests -gt 0 ]]; then
        exit 1
    fi
}

# Trap to ensure cleanup on exit
trap 'echo -e "\n${YELLOW}Tests interrupted${NC}"' INT TERM

main "$@"
