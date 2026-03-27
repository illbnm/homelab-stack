#!/bin/bash
# =============================================================================
# HomeLab Stack — Integration Test Runner
# =============================================================================
# Usage: ./run-tests.sh [--stack <name>] [--all] [--e2e] [--json] [--verbose] [--help]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STACKS_DIR="$ROOT_DIR/stacks"
RESULTS_DIR="$SCRIPT_DIR/results"

# Source libraries
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"

# Helper functions (must be defined before use due to set -u)
show_help() {
    cat <<'EOF'
HomeLab Stack — Integration Test Runner

Usage: ./run-tests.sh [OPTIONS]

OPTIONS:
  --stack <name>    Run tests for a specific stack (base|media|storage|
                    monitoring|network|productivity|ai|home-automation|
                    sso|databases|notifications)
  --all             Run all stack tests (default)
  --e2e             Run end-to-end tests only
  --json            Also write JSON report to tests/results/report.json
  --verbose         Verbose output
  --help, -h        Show this help message

EXAMPLES:
  ./run-tests.sh --stack base
  ./run-tests.sh --all
  ./run-tests.sh --e2e --json
  ./run-tests.sh --stack monitoring --json

EXIT CODE:
  0 = all tests passed
  1 = one or more tests failed
EOF
}

# CLI options
MODE="all"        # all | stack | e2e
TARGET_STACK=""   # e.g. base, media, databases
OUTPUT_JSON=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --stack)
            MODE="stack"
            TARGET_STACK="$2"
            shift 2
            ;;
        --all)
            MODE="all"
            shift
            ;;
        --e2e)
            MODE="e2e"
            shift
            ;;
        --json)
            OUTPUT_JSON=true
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

# Verify environment
check_environment() {
    echo -e "${C_CYAN}Checking environment...${C_RESET}"

    local errors=0

    if ! command -v docker &> /dev/null; then
        echo -e "${C_RED}ERROR: docker not found${C_RESET}"
        errors=$((errors + 1))
    fi

    if ! command -v jq &> /dev/null; then
        echo -e "${C_RED}ERROR: jq not found${C_RESET}"
        errors=$((errors + 1))
    fi

    if ! docker compose version &> /dev/null; then
        echo -e "${C_RED}ERROR: docker compose v2 not found${C_RESET}"
        errors=$((errors + 1))
    fi

    if [[ $errors -gt 0 ]]; then
        echo -e "${C_RED}Environment check failed. Install missing dependencies.${C_RESET}"
        exit 1
    fi

    echo -e "${C_GREEN}Environment OK${C_RESET}"
}

# Check if .env exists
check_env_file() {
    if [[ ! -f "$ROOT_DIR/.env" ]]; then
        echo -e "${C_YELLOW}WARNING: .env not found. Copy .env.example to .env first.${C_RESET}"
        echo -e "${C_YELLOW}Some tests may fail without environment variables.${C_RESET}"
    fi
}

# Load environment variables
load_env() {
    if [[ -f "$ROOT_DIR/.env" ]]; then
        set -a
        source "$ROOT_DIR/.env"
        set +a
    fi
}

# Run a test file
run_test_file() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file" .test.sh)

    if [[ ! -f "$test_file" ]]; then
        echo -e "${C_YELLOW}Test file not found: $test_file${C_RESET}"
        return
    fi

    reset_counters
    suite_start "$test_name"

    local start_time=$(date +%s.%N)

    # Run the test file (it sets TESTS_PASSED/FAILED/SKIPPED via assert.sh)
    bash "$test_file" || true

    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)

    suite_summary $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED

    # Accumulate global counters
    GLOBAL_PASSED=$((GLOBAL_PASSED + TESTS_PASSED))
    GLOBAL_FAILED=$((GLOBAL_FAILED + TESTS_FAILED))
    GLOBAL_SKIPPED=$((GLOBAL_SKIPPED + TESTS_SKIPPED))

    TOTAL_DURATION=$(echo "$TOTAL_DURATION + $duration" | bc)
}

# Global accumulators
GLOBAL_PASSED=0
GLOBAL_FAILED=0
GLOBAL_SKIPPED=0
TOTAL_DURATION=0

# =============================================================================
# Main
# =============================================================================

main() {
    report_banner

    check_environment
    check_env_file
    load_env

    local start_time=$(date +%s)

    echo ""

    case "$MODE" in
        all)
            echo -e "${C_BOLD}Running all stack tests...${C_RESET}"
            for test_file in "$SCRIPT_DIR/stacks"/*.test.sh; do
                run_test_file "$test_file"
            done
            ;;
        stack)
            echo -e "${C_BOLD}Running tests for stack: ${TARGET_STACK}${C_RESET}"
            local test_file="$SCRIPT_DIR/stacks/${TARGET_STACK}.test.sh"
            run_test_file "$test_file"
            ;;
        e2e)
            echo -e "${C_BOLD}Running E2E tests...${C_RESET}"
            for test_file in "$SCRIPT_DIR/e2e"/*.test.sh; do
                run_test_file "$test_file"
            done
            ;;
    esac

    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    echo ""
    report_summary $GLOBAL_PASSED $GLOBAL_FAILED $GLOBAL_SKIPPED $total_duration

    if $OUTPUT_JSON; then
        generate_json_report $GLOBAL_PASSED $GLOBAL_FAILED $GLOBAL_SKIPPED $total_duration
    fi

    if [[ $GLOBAL_FAILED -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main
