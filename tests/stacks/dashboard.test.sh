#!/usr/bin/env bash
# =============================================================================
# Dashboard Stack Tests (Homepage)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.."; pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/report.sh"

STACK_NAME="dashboard"
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env" 2>/dev/null || true

test_homepage_running() {
    local start=$(date +%s)
    assert_container_running "homepage" "Homepage running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "homepage_running" "$?" "$duration" "$STACK_NAME"
}

test_homepage_healthy() {
    local start=$(date +%s)
    assert_container_healthy "homepage" 60
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "homepage_healthy" "$?" "$duration" "$STACK_NAME"
}

test_homepage_webui() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:3010" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "homepage_webui" "$?" "$duration" "$STACK_NAME"
}

run_dashboard_tests() {
    report_init
    report_stack "Dashboard Stack"

    test_homepage_running
    test_homepage_healthy
    test_homepage_webui

    local duration=$(echo "$(date +%s) - $REPORT_START_TIME" | bc)
    report_summary $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
    report_export_json $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_dashboard_tests
fi
