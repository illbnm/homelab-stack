#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Import libraries
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"

# Default configuration
DEFAULT_LEVEL=1
DEFAULT_TIMEOUT=60
TEST_COMPOSE_FILE="$SCRIPT_DIR/ci/docker-compose.test.yml"

# Global variables
STACK_NAME=""
RUN_ALL=false
TEST_LEVEL=$DEFAULT_LEVEL
JSON_OUTPUT=false
CI_MODE=false
VERBOSE=false
TIMEOUT=$DEFAULT_TIMEOUT
FAILED_TESTS=()
PASSED_TESTS=()
SKIPPED_TESTS=()

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Test runner for HomeLab Stack integration tests.

OPTIONS:
    --stack <name>      Test specific stack (base, media, storage, etc.)
    --all              Test all stacks
    --level <1-3>      Test level: 1=health, 2=endpoints, 3=integration (default: 1)
    --json             Output results in JSON format
    --ci               CI mode - use test compose file, no interactive prompts
    --timeout <sec>    Timeout for container operations (default: 60)
    --verbose          Verbose output
    --help             Show this help

EXAMPLES:
    $0 --stack media --level 2
    $0 --all --json --ci
    $0 --stack base --verbose

AVAILABLE STACKS:
    base, media, storage, monitoring, network, productivity, ai, sso, databases, notifications

EOF
}

parse_args() {
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
            --level)
                TEST_LEVEL="$2"
                if [[ ! "$TEST_LEVEL" =~ ^[1-3]$ ]]; then
                    echo "Error: Invalid test level '$TEST_LEVEL'. Must be 1, 2, or 3."
                    exit 1
                fi
                shift 2
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --ci)
                CI_MODE=true
                shift
                ;;
            --timeout)
                TIMEOUT="$2"
                if [[ ! "$TIMEOUT" =~ ^[0-9]+$ ]]; then
                    echo "Error: Invalid timeout value '$TIMEOUT'. Must be a number."
                    exit 1
                fi
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                echo "Error: Unknown option '$1'"
                usage
                exit 1
                ;;
        esac
    done

    # Validation
    if [[ -z "$STACK_NAME" && "$RUN_ALL" != true ]]; then
        echo "Error: Must specify either --stack <name> or --all"
        usage
        exit 1
    fi

    if [[ -n "$STACK_NAME" && "$RUN_ALL" == true ]]; then
        echo "Error: Cannot specify both --stack and --all"
        usage
        exit 1
    fi
}

validate_environment() {
    log_info "Validating test environment..."

    # Check Docker availability
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi

    # Verify project structure
    if [[ ! -d "$PROJECT_ROOT/stacks" ]]; then
        log_error "Project stacks directory not found at $PROJECT_ROOT/stacks"
        exit 1
    fi

    # Check test compose file in CI mode
    if [[ "$CI_MODE" == true && ! -f "$TEST_COMPOSE_FILE" ]]; then
        log_error "Test compose file not found at $TEST_COMPOSE_FILE"
        exit 1
    fi

    log_success "Environment validation passed"
}

validate_stack_exists() {
    local stack="$1"
    local stack_dir="$PROJECT_ROOT/stacks/$stack"

    if [[ ! -d "$stack_dir" ]]; then
        log_error "Stack '$stack' not found at $stack_dir"
        return 1
    fi

    if [[ ! -f "$stack_dir/docker-compose.yml" ]]; then
        log_error "Stack '$stack' missing docker-compose.yml"
        return 1
    fi

    return 0
}

validate_compose_syntax() {
    local stack="$1"
    local compose_file="$PROJECT_ROOT/stacks/$stack/docker-compose.yml"

    log_info "Validating compose syntax for stack '$stack'"

    if docker-compose -f "$compose_file" config >/dev/null 2>&1; then
        log_success "Compose syntax valid for stack '$stack'"
        return 0
    elif docker compose -f "$compose_file" config >/dev/null 2>&1; then
        log_success "Compose syntax valid for stack '$stack'"
        return 0
    else
        log_error "Invalid compose syntax in stack '$stack'"
        return 1
    fi
}

check_configuration_integrity() {
    local stack="$1"
    local stack_dir="$PROJECT_ROOT/stacks/$stack"

    log_info "Checking configuration integrity for stack '$stack'"

    # Check for .env.example
    if [[ -f "$stack_dir/.env.example" ]]; then
        log_success "Found .env.example for stack '$stack'"
    else
        log_warning "Missing .env.example for stack '$stack'"
    fi

    # Check for README.md
    if [[ -f "$stack_dir/README.md" ]]; then
        log_success "Found documentation for stack '$stack'"
    else
        log_warning "Missing README.md for stack '$stack'"
    fi

    # Validate environment variables
    if [[ -f "$stack_dir/.env" ]]; then
        log_info "Found .env file for stack '$stack'"
        # TODO: Add more sophisticated env validation
    fi

    return 0
}

get_available_stacks() {
    find "$PROJECT_ROOT/stacks" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}

run_stack_test() {
    local stack="$1"
    local test_file="$SCRIPT_DIR/stacks/$stack.test.sh"

    if [[ ! -f "$test_file" ]]; then
        log_warning "Test file not found for stack '$stack' at $test_file"
        SKIPPED_TESTS+=("$stack:no-test-file")
        return 0
    fi

    log_info "Running tests for stack '$stack' (Level $TEST_LEVEL)"

    # Export configuration for test scripts
    export TEST_LEVEL
    export CI_MODE
    export VERBOSE
    export TIMEOUT
    export PROJECT_ROOT
    export SCRIPT_DIR

    # Run the test
    if bash "$test_file" 2>&1; then
        log_success "Tests passed for stack '$stack'"
        PASSED_TESTS+=("$stack")
        return 0
    else
        log_error "Tests failed for stack '$stack'"
        FAILED_TESTS+=("$stack")
        return 1
    fi
}

run_e2e_tests() {
    if [[ "$TEST_LEVEL" -lt 3 ]]; then
        return 0
    fi

    log_info "Running end-to-end tests..."

    local e2e_dir="$SCRIPT_DIR/e2e"
    if [[ ! -d "$e2e_dir" ]]; then
        log_warning "E2E test directory not found"
        return 0
    fi

    for test_file in "$e2e_dir"/*.test.sh; do
        if [[ -f "$test_file" ]]; then
            local test_name=$(basename "$test_file" .test.sh)
            log_info "Running E2E test: $test_name"

            if bash "$test_file" 2>&1; then
                log_success "E2E test passed: $test_name"
                PASSED_TESTS+=("e2e:$test_name")
            else
                log_error "E2E test failed: $test_name"
                FAILED_TESTS+=("e2e:$test_name")
            fi
        fi
    done
}

cleanup_test_environment() {
    if [[ "$CI_MODE" == true ]]; then
        log_info "Cleaning up CI test environment..."
        docker-compose -f "$TEST_COMPOSE_FILE" down -v --remove-orphans >/dev/null 2>&1 || true
    fi
}

generate_report() {
    local total_tests=$((${#PASSED_TESTS[@]} + ${#FAILED_TESTS[@]} + ${#SKIPPED_TESTS[@]}))
    local exit_code=0

    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        exit_code=1
    fi

    if [[ "$JSON_OUTPUT" == true ]]; then
        output_json_report "$total_tests" "${PASSED_TESTS[@]}" "${FAILED_TESTS[@]}" "${SKIPPED_TESTS[@]}"
    else
        output_terminal_report "$total_tests" "${PASSED_TESTS[@]}" "${FAILED_TESTS[@]}" "${SKIPPED_TESTS[@]}"
    fi

    return $exit_code
}

main() {
    # Initialize reporting
    init_report

    # Parse command line arguments
    parse_args "$@"

    # Validate environment
    validate_environment

    # Set up cleanup trap
    trap cleanup_test_environment EXIT

    # Initialize CI environment if needed
    if [[ "$CI_MODE" == true ]]; then
        log_info "Setting up CI test environment..."
        docker-compose -f "$TEST_COMPOSE_FILE" up -d >/dev/null 2>&1
        sleep 10  # Allow services to start
    fi

    # Run configuration validation tests
    log_section "Configuration Integrity Tests"

    if [[ "$RUN_ALL" == true ]]; then
        local stacks
        readarray -t stacks < <(get_available_stacks)

        for stack in "${stacks[@]}"; do
            if validate_stack_exists "$stack" && validate_compose_syntax "$stack"; then
                check_configuration_integrity "$stack"
            else
                FAILED_TESTS+=("$stack:config-validation")
            fi
        done
    else
        if validate_stack_exists "$STACK_NAME" && validate_compose_syntax "$STACK_NAME"; then
            check_configuration_integrity "$STACK_NAME"
        else
            FAILED_TESTS+=("$STACK_NAME:config-validation")
            generate_report
            exit 1
        fi
    fi

    # Run stack tests
    log_section "Stack Integration Tests"

    if [[ "$RUN_ALL" == true ]]; then
        local stacks
        readarray -t stacks < <(get_available_stacks)

        for stack in "${stacks[@]}"; do
            run_stack_test "$stack"
        done
    else
        run_stack_test "$STACK_NAME"
    fi

    # Run E2E tests if applicable
    if [[ "$RUN_ALL" == true ]]; then
        log_section "End-to-End Tests"
        run_e2e_tests
    fi

    # Generate final report
    log_section "Test Results"
    generate_report
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
