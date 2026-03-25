#!/bin/bash
# report.sh - Test result reporting (JSON + colored terminal output)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Report directory
REPORT_DIR="${REPORT_DIR:-./test-reports}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
JSON_REPORT="${REPORT_DIR}/report_${TIMESTAMP}.json"

# Initialize JSON report
report_init() {
    mkdir -p "$REPORT_DIR"
    cat > "$JSON_REPORT" << EOF
{
  "timestamp": "${TIMESTAMP}",
  "hostname": "$(hostname)",
  "tests": [],
  "summary": {
    "total": 0,
    "passed": 0,
    "failed": 0,
    "skipped": 0
  }
}
EOF
}

# Add test result to JSON
report_add_test() {
    local test_name="$1"
    local status="$2"  # pass, fail, skip
    local message="${3:-}"
    local duration="${4:-0}"

    local temp_file="${REPORT_DIR}/temp_$$.json"

    # Read current JSON and add test
    python3 << PYEOF > "$temp_file" 2>/dev/null
import json

with open("$JSON_REPORT", "r") as f:
    report = json.load(f)

test_entry = {
    "name": "$test_name",
    "status": "$status",
    "message": "$message",
    "duration": $duration
}

report["tests"].append(test_entry)
report["summary"]["total"] += 1
if "$status" == "passed":
    report["summary"]["passed"] += 1
elif "$status" == "failed":
    report["summary"]["failed"] += 1
else:
    report["summary"]["skipped"] += 1

with open("$JSON_REPORT", "w") as f:
    json.dump(report, f, indent=2)
PYEOF

    rm -f "$temp_file"
}

# Print colored status
report_status() {
    local status="$1"
    case "$status" in
        pass)
            echo -e "${GREEN}✓ PASS${NC}"
            ;;
        fail)
            echo -e "${RED}✗ FAIL${NC}"
            ;;
        skip)
            echo -e "${YELLOW}⊘ SKIP${NC}"
            ;;
        info)
            echo -e "${BLUE}ℹ INFO${NC}"
            ;;
        *)
            echo -e "${CYAN}• $status${NC}"
            ;;
    esac
}

# Print section header
report_section() {
    local section="$1"
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $section${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Print test result with formatting
report_test() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    local duration="$4"

    printf "  %-50s " "$test_name"

    case "$status" in
        pass)
            echo -e "${GREEN}✓${NC}"
            ;;
        fail)
            echo -e "${RED}✗${NC}"
            ;;
        skip)
            echo -e "${YELLOW}⊘${NC}"
            ;;
    esac

    if [ -n "$message" ] && [ "$status" = "fail" ]; then
        echo -e "    ${RED}$message${NC}"
    fi

    if [ -n "$duration" ]; then
        echo -e "    ${CYAN}Duration: ${duration}s${NC}"
    fi
}

# Print summary
report_summary() {
    local total="$1"
    local passed="$2"
    local failed="$3"
    local skipped="$4"
    local duration="$5"

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  TEST SUMMARY${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "  Total:   ${total}"
    echo -e "  Passed:  ${GREEN}${passed}${NC}"
    echo -e "  Failed:  ${RED}${failed}${NC}"
    echo -e "  Skipped: ${YELLOW}${skipped}${NC}"
    echo ""

    if [ -n "$duration" ]; then
        echo -e "  Duration: ${CYAN}${duration}s${NC}"
    fi

    echo ""
    echo -e "  JSON Report: ${JSON_REPORT}"
    echo ""
}

# Print header
report_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Homelab-Stack Test Runner        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Timestamp: ${TIMESTAMP}"
    echo -e "  Hostname: $(hostname)"
    echo ""
}

# Print footer
report_footer() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  Test run completed${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# Export functions
export -f report_init report_add_test
export -f report_status report_section
export -f report_test report_summary
export -f report_header report_footer
export REPORT_DIR JSON_REPORT TIMESTAMP
