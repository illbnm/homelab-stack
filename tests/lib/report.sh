#!/usr/bin/env bash
# =============================================================================
# Report Library — HomeLab Stack Integration Tests
# Outputs both terminal (colored) and JSON formats
# =============================================================================

REPORT_DIR="${REPORT_DIR:-$(dirname "$0")/../results}"
REPORT_FILE="$REPORT_DIR/report.json"

# Colors for terminal output
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'
DIM='\033[2m'; NC='\033[0m'

# Test results array for JSON export
declare -a JSON_RESULTS=()
REPORT_START_TIME=""

# Initialize report
report_init() {
    REPORT_START_TIME=$(date +%s)
    JSON_RESULTS=()
    mkdir -p "$REPORT_DIR"
}

# Add a test result
report_add_result() {
    local test_name="$1"
    local status="$2"       # pass | fail | skip
    local duration="$3"     # seconds (float)
    local stack="$4"        # e.g. "base", "media"
    local message="${5:-}"

    # Terminal output (colored)
    case "$status" in
        pass)
            echo -e "  ${GREEN}✓${NC} $test_name ${DIM}${duration}s${NC}"
            ;;
        fail)
            echo -e "  ${RED}✗${NC} $test_name ${DIM}${duration}s${NC}"
            [[ -n "$message" ]] && echo -e "    ${RED}→${NC} $message"
            ;;
        skip)
            echo -e "  ${YELLOW}~${NC} $test_name ${DIM}(skipped)${NC}"
            ;;
    esac

    # JSON result
    local json_result
    json_result=$(printf '{"name":"%s","status":"%s","duration":%s,"stack":"%s","message":"%s","timestamp":"%s"}' \
        "$test_name" "$status" "$duration" "$stack" "$message" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    JSON_RESULTS+=("$json_result")
}

# Print section header
report_section() {
    local stack="$1"
    echo ""
    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║${NC}  $stack".$(printf '%*s' $((36 - ${#stack})) '')
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════╝${NC}"
}

# Print test section header (lighter)
report_stack() {
    local name="$1"
    echo ""
    echo -e "${CYAN}[$name]${NC}"
}

# Export JSON report
report_export_json() {
    local passed="$1"
    local failed="$2"
    local skipped="$3"
    local duration="$4"
    local output_file="${5:-$REPORT_FILE}"

    local json
    json=$(printf '{
  "suite": "homelab-stack-integration-tests",
  "timestamp": "%s",
  "duration": %s,
  "summary": {
    "passed": %s,
    "failed": %s,
    "skipped": %s,
    "total": %s
  },
  "results": [%s]
}' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$duration" \
        "$passed" "$failed" "$skipped" \
        $((passed + failed + skipped)) \
        "$(IFS=,; echo "${JSON_RESULTS[*]}")")

    echo "$json" > "$output_file"
    echo -e "${DIM}JSON report written to: $output_file${NC}"
}

# Print summary to terminal
report_summary() {
    local passed="$1"
    local failed="$2"
    local skipped="$3"
    local duration="$4"

    echo ""
    echo -e "${BOLD}──────────────────────────────────────${NC}"
    echo -e "  Results: ${GREEN}$passed passed${NC} | ${RED}$failed failed${NC} | ${YELLOW}$skipped skipped${NC}"
    echo -e "  Duration: ${duration}s"
    echo -e "${BOLD}──────────────────────────────────────${NC}"

    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}  ✓ ALL TESTS PASSED${NC}"
    else
        echo -e "${RED}${BOLD}  ✗ SOME TESTS FAILED${NC}"
    fi
}
