#!/usr/bin/env bash
# report.sh - Test result reporting (JSON + colored terminal)
# Copyright (c) 2026 homelab-stack contributors
# SPDX-License-Identifier: MIT

# Colors
readonly _R_RED='\033[0;31m'
readonly _R_GREEN='\033[0;32m'
readonly _R_YELLOW='\033[0;33m'
readonly _R_BLUE='\033[0;34m'
readonly _R_CYAN='\033[0;36m'
readonly _R_BOLD='\033[1m'
readonly _R_RESET='\033[0m'

# Internal: associative-array-like storage using temp file
_REPORT_RESULTS_DIR="${REPORT_RESULTS_DIR:-/tmp/homelab-stack/tests/results}"
_REPORT_RESULTS_FILE="${_REPORT_RESULTS_DIR}/results.json"
_REPORT_CURRENT_STACK=""
_REPORT_TEST_RESULTS=()  # lines of JSON objects
_REPORT_TIMESTAMPS=()

# Initialize report
report_init() {
    _REPORT_CURRENT_STACK="$1"
    _REPORT_TEST_RESULTS=()
    _REPORT_TIMESTAMPS=()
    echo -e "\n${_R_BOLD}${_R_CYAN}━━━ Stack: ${_REPORT_CURRENT_STACK} ━━━${_R_RESET}"
}

# Record a single test result
report_record_test() {
    local test_name="$1" status="$2" message="$3" detail="${4:-}"
    local duration_ms=0
    # Calculate duration if we have timestamps
    local ts
    ts=$(date +%s%N 2>/dev/null || date +%s)
    if [ ${#_REPORT_TIMESTAMPS[@]} -gt 0 ]; then
        local prev=${_REPORT_TIMESTAMPS[-1]}
        local now
        now=$(date +%s%N 2>/dev/null || echo "${ts}000000000")
        # Fallback: just set 0 if date +%s%N not supported
        duration_ms=0
    fi
    _REPORT_TIMESTAMPS+=("$ts")

    # Escape strings for JSON
    local escaped_test escaped_msg escaped_detail
    escaped_test=$(echo "$test_name" | sed 's/"/\\"/g' | tr '\n' ' ')
    escaped_msg=$(echo "$message" | sed 's/"/\\"/g' | tr '\n' ' ')
    escaped_detail=$(echo "$detail" | sed 's/"/\\"/g' | tr '\n' ' ')

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u)

    local entry="{\"stack\":\"${_REPORT_CURRENT_STACK}\",\"test\":\"${escaped_test}\",\"status\":\"${status}\",\"message\":\"${escaped_msg}\",\"detail\":\"${escaped_detail}\",\"timestamp\":\"${timestamp}\"}"
    _REPORT_TEST_RESULTS+=("$entry")
}

# Write results to JSON file
report_write_json() {
    local total=${#_REPORT_TEST_RESULTS[@]}
    local passed=0 failed=0 skipped=0

    # Count by status
    for entry in "${_REPORT_TEST_RESULTS[@]}"; do
        local s
        s=$(echo "$entry" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        case "$s" in
            pass) passed=$((passed + 1)) ;;
            fail) failed=$((failed + 1)) ;;
            skip) skipped=$((skipped + 1)) ;;
        esac
    done

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u)

    mkdir -p "$_REPORT_RESULTS_DIR"

    cat > "$_REPORT_RESULTS_FILE" <<EOF
{
  "timestamp": "${timestamp}",
  "summary": {
    "total": ${total},
    "passed": ${passed},
    "failed": ${failed},
    "skipped": ${skipped}
  },
  "results": [
$(local first=true
for entry in "${_REPORT_TEST_RESULTS[@]}"; do
    $first && first=false || echo ","
    echo -n "    ${entry}"
done)
  ]
}
EOF

    echo -e "\n${_R_CYAN}Results written to: ${_REPORT_RESULTS_FILE}${_R_RESET}"
}

# Print terminal summary
report_print_summary() {
    local total=${#_REPORT_TEST_RESULTS[@]}
    local passed=0 failed=0 skipped=0

    for entry in "${_REPORT_TEST_RESULTS[@]}"; do
        local s
        s=$(echo "$entry" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        case "$s" in
            pass) passed=$((passed + 1)) ;;
            fail) failed=$((failed + 1)) ;;
            skip) skipped=$((skipped + 1)) ;;
        esac
    done

    echo -e "\n${_R_BOLD}┌────────────────────────────────────────┐${_R_RESET}"
    echo -e "${_R_BOLD}│           Test Summary                   │${_R_RESET}"
    echo -e "${_R_BOLD}├────────────────────────────────────────┤${_R_RESET}"
    echo -e "│  Total:   ${_R_BOLD}${total}${_R_RESET}                            │"
    echo -e "│  ${_R_GREEN}Passed:  ${passed}${_R_RESET}                            │"
    echo -e "│  ${_R_RED}Failed:  ${failed}${_R_RESET}                            │"
    echo -e "│  ${_R_YELLOW}Skipped: ${skipped}${_R_RESET}                            │"
    echo -e "${_R_BOLD}└────────────────────────────────────────┘${_R_RESET}"

    if [ "$failed" -gt 0 ]; then
        echo -e "\n${_R_RED}${_R_BOLD}❌ Some tests failed!${_R_RESET}"
        return 1
    elif [ "$total" -eq 0 ]; then
        echo -e "\n${_R_YELLOW}⚠ No tests were executed${_R_RESET}"
        return 1
    else
        echo -e "\n${_R_GREEN}${_R_BOLD}✅ All tests passed!${_R_RESET}"
        return 0
    fi
}

# Print results table
report_print_table() {
    printf "  %-12s %-40s %-6s %s\n" "STACK" "TEST" "STATUS" "MESSAGE"
    printf "  %-12s %-40s %-6s %s\n" "-----" "----" "------" "-------"
    for entry in "${_REPORT_TEST_RESULTS[@]}"; do
        local stack test status message
        stack=$(echo "$entry" | grep -o '"stack":"[^"]*"' | cut -d'"' -f4)
        test=$(echo "$entry" | grep -o '"test":"[^"]*"' | cut -d'"' -f4)
        status=$(echo "$entry" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        message=$(echo "$entry" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)

        local color
        case "$status" in
            pass) color="$_R_GREEN" ;;
            fail) color="$_R_RED" ;;
            skip) color="$_R_YELLOW" ;;
            *)    color="$_R_RESET" ;;
        esac

        local short_test="${test:0:38}"
        local short_msg="${message:0:30}"
        printf "  %-12s %-40s ${color}%-6s${_R_RESET} %s\n" "$stack" "$short_test" "${status^^}" "$short_msg"
    done
}
