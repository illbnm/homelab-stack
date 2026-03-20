#!/bin/bash

# Test runner for HomeLab Stack integration tests

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_STACK="stacks/base/docker-compose.yml"
RESULTS_DIR="tests/results"
JSON_REPORT="$RESULTS_DIR/report.json"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Load assertion library
source tests/lib/assert.sh

# Print header
print_header() {
    echo ""
    echo "╔═════════════════════════════════════════════════════╗"
    echo "║ HomeLab Stack — Integration Tests ║"
    echo "╚═════════════════════════════════════════════════════╝"
    echo ""
}

# Print summary
print_summary() {
    local passed=$1
    local failed=$2
    local skipped=$3
    local duration=$4
    
    echo ""
    echo "─────────────────────────────────────────────────────"
    echo "Results: $passed passed, $failed failed, $skipped skipped"
    echo "Duration: ${duration}s"
    echo "─────────────────────────────────────────────────────"
}

# Run individual test files
run_test_file() {
    local test_file="$1"
    local test_name="$2"
    local start_time=$(date +%s)
    
    log_info "Running $test_name..."
    
    if bash "$test_file"; then
        local duration=$(( $(date +%s) - start_time ))
        log_success "$test_name ✅ PASS (${duration}s)"
        return 0
    else
        local duration=$(( $(date +%s) - start_time ))
        log_error "$test_name ❌ FAIL (${duration}s)"
        return 1
    fi
}

# Main test runner
main() {
    local stack="${1:-base}"
    local json_output="${2:-false}"
    local start_time=$(date +%s)
    local passed=0
    local failed=0
    local skipped=0
    
    print_header
    
    # Setup
    if [[ "$stack" == "base" ]]; then
        log_info "Starting base stack..."
        if docker compose -f "$BASE_STACK" up -d; then
            log_success "Base stack started"
        else
            log_error "Failed to start base stack"
            exit 1
        fi
        
        log_info "Waiting for services to be healthy..."
        if ! wait_for_healthy 120; then
            log_error "Services not healthy after 120 seconds"
            exit 1
        fi
    fi
    
    # Create results directory
    mkdir -p "$RESULTS_DIR"
    
    # Run tests based on stack
    case "$stack" in
        "base")
            log_info "Running base stack tests..."
            
            # Container health tests
            run_test_file "tests/stacks/base.test.sh" "[base] Container Health Tests"
            (( $? == 0 )) && ((passed++)) || ((failed++))
            
            # HTTP endpoint tests
            run_test_file "tests/stacks/http.test.sh" "[base] HTTP Endpoint Tests"
            (( $? == 0 )) && ((passed++)) || ((failed++))
            
            # Configuration tests
            run_test_file "tests/stacks/config.test.sh" "[base] Configuration Tests"
            (( $? == 0 )) && ((passed++)) || ((failed++))
            ;;
        "all")
            log_info "Running all stack tests..."
            # TODO: Implement all stack tests
            ((skipped++))
            ;;
        *)
            log_error "Unknown stack: $stack"
            exit 1
            ;;
    esac
    
    local duration=$(( $(date +%s) - start_time ))
    
    print_summary "$passed" "$failed" "$skipped" "$duration"
    
    # Generate JSON report
    if [[ "$json_output" == "true" ]]; then
        cat > "$JSON_REPORT" << EOF
{
    "summary": {
        "passed": $passed,
        "failed": $failed,
        "skipped": $skipped,
        "duration": $duration,
        "timestamp": "$(date -Iseconds)"
    },
    "details": {
        "base": {
            "passed": $passed,
            "failed": $failed,
            "skipped": $skipped
        }
    }
}
EOF
        log_success "JSON report saved to $JSON_REPORT"
    fi
    
    # Exit with failure if any tests failed
    if [[ "$failed" -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Help
print_help() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  run [stack]      Run integration tests for specified stack (default: base)"
    echo "  help             Show this help message"
    echo ""
    echo "Options:"
    echo "  --stack <name>   Specify which stack to test (base, all, etc.)"
    echo "  --json           Output results in JSON format"
    echo "  --help           Show help message"
}

# Parse command line arguments
if [[ $# -eq 0 ]] || [[ "$1" == "run" ]]; then
    main "${2:-base}" "${3:-false}"
elif [[ "$1" == "help" ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    print_help
else
    log_error "Unknown command: $1"
    print_help
    exit 1
fi