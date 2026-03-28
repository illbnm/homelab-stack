#!/usr/bin/env bash
# =============================================================================
# Home Automation Stack Tests (Home Assistant, Node-RED)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.."; pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/report.sh"

STACK_NAME="home-automation"
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env" 2>/dev/null || true

test_homeassistant_running() {
    local start=$(date +%s)
    assert_container_running "homeassistant" "Home Assistant running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "homeassistant_running" "$?" "$duration" "$STACK_NAME"
}

test_nodered_running() {
    local start=$(date +%s)
    assert_container_running "node-red" "Node-RED running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "nodered_running" "$?" "$duration" "$STACK_NAME"
}

test_homeassistant_api() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:8123/api/" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "homeassistant_api" "$?" "$duration" "$STACK_NAME"
}

test_nodered_webui() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:1880" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "nodered_webui" "$?" "$duration" "$STACK_NAME"
}

run_home_automation_tests() {
    report_init
    report_stack "Home Automation Stack"

    test_homeassistant_running
    test_nodered_running
    test_homeassistant_api
    test_nodered_webui

    local duration=$(echo "$(date +%s) - $REPORT_START_TIME" | bc)
    report_summary $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
    report_export_json $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_home_automation_tests
fi
