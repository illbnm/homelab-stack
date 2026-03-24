#!/usr/bin/env bash
# ==============================================================================
# HomeLab Stack — Integration Test Runner
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"

# Source libraries
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# Default options
STACK=""
RUN_ALL=false
JSON_OUTPUT=false
VERBOSE=false
TIMEOUT=300

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --stack <name>    Run tests for specific stack only
  --all             Run all stack tests
  --json            Output results as JSON to tests/results/report.json
  --verbose         Show detailed output
  --timeout <sec>   Set timeout for health checks (default: 300)
  --help            Show this help message

Examples:
  $(basename "$0") --stack base
  $(basename "$0") --all --json
  $(basename "$0") --stack media --verbose

Available stacks:
  base, media, storage, monitoring, network, productivity,
  ai, home-automation, sso, databases, notifications
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --stack) STACK="$2"; shift 2 ;;
        --all) RUN_ALL=true; shift ;;
        --json) JSON_OUTPUT=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --help|-h) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# Banner
print_banner() {
    echo -e "\n${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║   HomeLab Stack — Integration Tests  ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════╝${NC}\n"
}

# Run tests for a specific stack
run_stack_tests() {
    local stack=$1
    local test_file="$SCRIPT_DIR/stacks/${stack}.test.sh"
    
    if [[ ! -f "$test_file" ]]; then
        log_skip "No test file found for stack: $stack"
        return 0
    fi
    
    log_group "$stack"
    source "$test_file"
}

# Main
main() {
    print_banner
    
    # Check Docker is running
    if ! docker info &>/dev/null; then
        echo -e "${RED}Error: Docker daemon is not running${NC}"
        exit 1
    fi
    
    # Load environment
    if [[ -f "$ENV_FILE" ]]; then
        set -a; source "$ENV_FILE"; set +a
    fi
    
    # Initialize counters
    PASSED=0; FAILED=0; SKIPPED=0
    START_TIME=$(date +%s)
    
    if [[ -n "$STACK" ]]; then
        run_stack_tests "$STACK"
    elif [[ "$RUN_ALL" == true ]]; then
        for test_file in "$SCRIPT_DIR/stacks"/*.test.sh; do
            [[ -f "$test_file" ]] || continue
            local stack_name=$(basename "$test_file" .test.sh)
            run_stack_tests "$stack_name"
        done
    else
        echo -e "${YELLOW}No test specified. Use --stack <name> or --all${NC}"
        usage
    fi
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    # Print summary
    print_summary "$PASSED" "$FAILED" "$SKIPPED" "$DURATION"
    
    # JSON output
    if [[ "$JSON_OUTPUT" == true ]]; then
        write_json_report "$PASSED" "$FAILED" "$SKIPPED" "$DURATION"
    fi
    
    # Exit code
    if [[ $FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"