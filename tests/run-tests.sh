#!/bin/bash
# =============================================================================
# HomeLab Stack - Test Runner
# =============================================================================

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the assertion library
source "$SCRIPT_DIR/lib/assert.sh"

# Default values
VERBOSE=false
RUN_STACKS=true
RUN_E2E=false
STACKS_TO_TEST=()

# -----------------------------------------------------------------------------
# Usage information
# -----------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

HomeLab Stack Integration Test Runner

OPTIONS:
    -h, --help           Show this help message
    -v, --verbose        Enable verbose output
    --stacks-only        Run stack tests only (default)
    --e2e-only           Run e2e tests only
    --all                Run all tests (stacks + e2e)
    --stack STACK        Run specific stack test (can be repeated)
    
EXAMPLES:
    $0                           # Run all stack tests
    $0 --stack base              # Run only base stack tests
    $0 --stack monitoring --stack databases  # Run multiple stacks
    $0 --all                     # Run stacks and e2e tests

STACKS AVAILABLE:
    base, databases, monitoring, network, storage, media, 
    productivity, ai, sso, notifications, dashboard, home-automation
EOF
    exit 0
}

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --stacks-only)
            RUN_STACKS=true
            RUN_E2E=false
            shift
            ;;
        --e2e-only)
            RUN_STACKS=false
            RUN_E2E=true
            shift
            ;;
        --all)
            RUN_STACKS=true
            RUN_E2E=true
            shift
            ;;
        --stack)
            STACKS_TO_TEST+=("$2")
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Change to project root
cd "$PROJECT_ROOT"

# -----------------------------------------------------------------------------
# Pre-flight checks
# -----------------------------------------------------------------------------
log_info "Running pre-flight checks..."

# Check if Docker is available
if ! command -v docker &>/dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &>/dev/null; then
    log_error "Docker daemon is not running"
    exit 1
fi

# Check if docker compose is available
if ! docker compose version &>/dev/null; then
    log_error "Docker Compose is not available"
    exit 1
fi

log_success "Pre-flight checks passed"

# -----------------------------------------------------------------------------
# Discover available stacks
# -----------------------------------------------------------------------------
discover_stacks() {
    local stacks_dir="$PROJECT_ROOT/stacks"
    if [[ -d "$stacks_dir" ]]; then
        find "$stacks_dir" -maxdepth 1 -type d -not -name "stacks" | xargs -n1 basename 2>/dev/null || true
    fi
}

# -----------------------------------------------------------------------------
# Run stack tests
# -----------------------------------------------------------------------------
run_stack_tests() {
    local stack_name="$1"
    local test_file="$SCRIPT_DIR/stacks/${stack_name}.test.sh"
    
    if [[ ! -f "$test_file" ]]; then
        log_warn "No test file found for stack: $stack_name"
        return 0
    fi
    
    describe "Testing stack: $stack_name"
    source "$test_file"
}

# -----------------------------------------------------------------------------
# Run all stack tests
# -----------------------------------------------------------------------------
run_all_stack_tests() {
    local all_stacks=(base databases monitoring network storage media productivity ai sso notifications dashboard home-automation)
    
    for stack in "${all_stacks[@]}"; do
        # Check if stack directory exists
        if [[ -d "$PROJECT_ROOT/stacks/$stack" ]]; then
            run_stack_tests "$stack"
        fi
    done
}

# -----------------------------------------------------------------------------
# Run specific stack tests
# -----------------------------------------------------------------------------
run_specific_stack_tests() {
    for stack in "${STACKS_TO_TEST[@]}"; do
        if [[ -d "$PROJECT_ROOT/stacks/$stack" ]]; then
            run_stack_tests "$stack"
        else
            log_warn "Stack directory not found: $stack"
        fi
    done
}

# -----------------------------------------------------------------------------
# Run e2e tests
# -----------------------------------------------------------------------------
run_e2e_tests() {
    local e2e_dir="$SCRIPT_DIR/e2e"
    
    if [[ ! -d "$e2e_dir" ]]; then
        log_warn "No e2e tests directory found"
        return 0
    fi
    
    describe "End-to-End Tests"
    
    for test_file in "$e2e_dir"/*.test.sh; do
        if [[ -f "$test_file" ]]; then
            local test_name
            test_name=$(basename "$test_file" .test.sh)
            describe "E2E: $test_name"
            source "$test_file"
        fi
    done
}

# -----------------------------------------------------------------------------
# Main execution
# -----------------------------------------------------------------------------
main() {
    log_info "Starting HomeLab Stack Test Suite"
    log_info "Project root: $PROJECT_ROOT"
    
    # Run stack tests
    if [[ "$RUN_STACKS" == true ]]; then
        if [[ ${#STACKS_TO_TEST[@]} -gt 0 ]]; then
            run_specific_stack_tests
        else
            run_all_stack_tests
        fi
    fi
    
    # Run e2e tests
    if [[ "$RUN_E2E" == true ]]; then
        run_e2e_tests
    fi
    
    # Print summary
    print_summary
    
    # Exit with appropriate code
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"