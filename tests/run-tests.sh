#!/bin/bash
# =============================================================================
# run-tests.sh - Integration test runner
# Usage: ./run-tests.sh --stack <name> | --all [--json]
# =============================================================================

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"

# Default values
STACK=""
JSON_OUTPUT=false
VERBOSE=false

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------

show_help() {
    cat << HELPEOF
HomeLab Stack Integration Tests

Usage: $(basename "$0") [OPTIONS]

Options:
  --stack <name>    Run tests for specific stack
  --all             Run tests for all stacks
  --json            Output JSON report to tests/results/report.json
  --verbose         Show verbose output
  --help            Show this help message

Available stacks:
  base, media, storage, databases, network, productivity,
  ai, home-automation, notifications, sso

Examples:
  $(basename "$0") --stack base
  $(basename "$0") --all --json
  $(basename "$0") --stack media --verbose

HELPEOF
}

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case $1 in
        --stack)
            STACK="$2"
            shift 2
            ;;
        --all)
            STACK="all"
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------

if [[ -z "$STACK" ]]; then
    echo "Error: --stack or --all required"
    show_help
    exit 1
fi

# -----------------------------------------------------------------------------
# Run tests
# -----------------------------------------------------------------------------

print_header

START_TIME=$(date +%s)

run_stack_tests() {
    local stack="$1"
    local test_file="$SCRIPT_DIR/stacks/${stack}.test.sh"
    
    if [[ ! -f "$test_file" ]]; then
        print_stack_header "$stack"
        print_test_result "Tests not found" "SKIP" 0 "No test file at $test_file"
        return 0
    fi
    
    print_stack_header "$stack"
    source "$test_file"
}

if [[ "$STACK" == "all" ]]; then
    for stack in base media storage databases network productivity ai home-automation notifications sso; do
        run_stack_tests "$stack"
    done
else
    run_stack_tests "$STACK"
fi

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

print_summary "$TOTAL_DURATION"

if $JSON_OUTPUT; then
    generate_json_report "$SCRIPT_DIR/results/report.json" "$TOTAL_DURATION"
fi

# Exit with error if any tests failed
if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
