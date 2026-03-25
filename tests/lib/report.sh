#!/bin/bash
# =============================================================================
# report.sh - Test result reporting
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TESTS_TOTAL=0

# Current stack
CURRENT_STACK=""

# Results array for JSON
declare -a TEST_RESULTS=()

# -----------------------------------------------------------------------------
# Output functions
# -----------------------------------------------------------------------------

print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   HomeLab Stack — Integration Tests  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""
}

print_stack_header() {
    local stack="$1"
    CURRENT_STACK="$stack"
    echo ""
    echo -e "${BOLD}[$stack]${NC}"
}

print_test_result() {
    local name="$1"
    local result="$2"
    local duration="${3:-0}"
    local error_msg="${4:-}"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    local status_icon
    local status_color
    
    case "$result" in
        PASS)
            status_icon="✅"
            status_color="$GREEN"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            ;;
        FAIL)
            status_icon="❌"
            status_color="$RED"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            ;;
        SKIP)
            status_icon="⏭️"
            status_color="$YELLOW"
            TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
            ;;
    esac
    
    echo -e "  ${status_color}▶${NC} $name ${status_icon} ${status_color}${result}${NC} (${duration}s)"
    
    if [[ -n "$error_msg" && "$result" == "FAIL" ]]; then
        echo -e "    ${RED}$error_msg${NC}"
    fi
    
    # Store for JSON
    TEST_RESULTS+=("{\"stack\":\"$CURRENT_STACK\",\"name\":\"$name\",\"result\":\"$result\",\"duration\":$duration}")
}

print_summary() {
    local total_duration="${1:-0}"
    
    echo ""
    echo "──────────────────────────────────────"
    echo -e "Results: ${GREEN}$TESTS_PASSED passed${NC}, ${RED}$TESTS_FAILED failed${NC}, ${YELLOW}$TESTS_SKIPPED skipped${NC}"
    echo "Duration: ${total_duration}s"
    echo "──────────────────────────────────────"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# JSON output
# -----------------------------------------------------------------------------

generate_json_report() {
    local output_file="${1:-tests/results/report.json}"
    local total_duration="${2:-0}"
    
    mkdir -p "$(dirname "$output_file")"
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    {
        echo "{"
        echo "  \"timestamp\": \"$timestamp\","
        echo "  \"summary\": {"
        echo "    \"total\": $TESTS_TOTAL,"
        echo "    \"passed\": $TESTS_PASSED,"
        echo "    \"failed\": $TESTS_FAILED,"
        echo "    \"skipped\": $TESTS_SKIPPED,"
        echo "    \"duration\": $total_duration"
        echo "  },"
        echo "  \"tests\": ["
        
        local first=true
        for result in "${TEST_RESULTS[@]}"; do
            if $first; then
                echo "    $result"
                first=false
            else
                echo "    ,$result"
            fi
        done
        
        echo "  ]"
        echo "}"
    } > "$output_file"
    
    echo "JSON report: $output_file"
}
