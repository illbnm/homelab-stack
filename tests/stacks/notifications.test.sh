#!/usr/bin/env bash
# =============================================================================
# Notifications Stack Tests (ntfy)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.."; pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/report.sh"

STACK_NAME="notifications"
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env" 2>/dev/null || true

test_ntfy_running() {
    local start=$(date +%s)
    assert_container_running "ntfy" "ntfy running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "ntfy_running" "$?" "$duration" "$STACK_NAME"
}

test_ntfy_healthy() {
    local start=$(date +%s)
    assert_container_healthy "ntfy" 60
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "ntfy_healthy" "$?" "$duration" "$STACK_NAME"
}

test_ntfy_health_endpoint() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:2586/health" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "ntfy_health" "$?" "$duration" "$STACK_NAME"
}

test_ntfy_static() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:2586/static" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "ntfy_static" "$?" "$duration" "$STACK_NAME"
}

run_notifications_tests() {
    report_init
    report_stack "Notifications Stack"

    test_ntfy_running
    test_ntfy_healthy
    test_ntfy_health_endpoint
    test_ntfy_static

    local duration=$(echo "$(date +%s) - $REPORT_START_TIME" | bc)
    report_summary $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
    report_export_json $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_notifications_tests
fi
