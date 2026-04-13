#!/usr/bin/env bash
# Test report utilities
# Copyright (c) 2026 思捷娅科技 (SJYKJ) | License: MIT

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

RESULTS_DIR="tests/results"
JSON_REPORT="${RESULTS_DIR}/report.json"

# Initialize report
report_init() {
    mkdir -p "$RESULTS_DIR"
    echo '{"tests":[],"started":"'$(date -Iseconds)'"}' > "$JSON_REPORT"
    TEST_START_TIME=$(date +%s)
}

# Record a test result
report_record() {
    local stack="$1" name="$2" status="$3" duration="${4:-0}"
    local tmp
    tmp=$(mktemp)
    jq --arg stack "$stack" --arg name "$name" --arg status "$status" \
       --arg duration "$duration" \
       '.tests += [{"stack":$stack,"name":$name,"status":$status,"duration":$duration}]' \
       "$JSON_REPORT" > "$tmp" && mv "$tmp" "$JSON_REPORT"
}

# Print final summary
report_summary() {
    local total=$((ASSERT_PASS + ASSERT_FAIL + ASSERT_SKIP))
    local duration=$(($(date +%s) - TEST_START_TIME))

    echo ""
    echo "──────────────────────────────────────────────"
    echo -e "Results: ${GREEN}${ASSERT_PASS} passed${NC}, ${RED}${ASSERT_FAIL} failed${NC}, ${YELLOW}${ASSERT_SKIP} skipped${NC}"
    echo "Duration: ${duration}s"
    echo "──────────────────────────────────────────────"

    # Update JSON report
    local tmp
    tmp=$(mktemp)
    jq --argjson pass "$ASSERT_PASS" --argjson fail "$ASSERT_FAIL" \
       --argjson skip "$ASSERT_SKIP" --arg duration "${duration}s" \
       '. + {"summary":{"passed":$pass,"failed":$fail,"skipped":$skip,"duration":$duration},"finished":"'$(date -Iseconds)'"}' \
       "$JSON_REPORT" > "$tmp" && mv "$tmp" "$JSON_REPORT"

    echo "Report saved to ${JSON_REPORT}"

    # Exit with failure if any test failed
    if [[ $ASSERT_FAIL -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Print test header
print_header() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║   HomeLab Stack — Integration Tests  ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
}

# Print a single test result
print_test() {
    local stack="$1" name="$2" status="$3" duration="${4:-0}"
    local icon
    case "$status" in
        PASS)    icon="${GREEN}✅ PASS${NC}" ;;
        FAIL)    icon="${RED}❌ FAIL${NC}" ;;
        SKIP)    icon="${YELLOW}⏭️ SKIP${NC}" ;;
    esac
    printf "  [%-12s] ▶ %-30s %s (%ss)\n" "$stack" "$name" "$(echo -e $icon)" "$duration"
}
