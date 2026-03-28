#!/usr/bin/env bash
# =============================================================================
# Network Stack Tests (AdGuard, Nginx-Proxy-Manager, WireGuard)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.."; pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/report.sh"

STACK_NAME="network"
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env" 2>/dev/null || true

test_adguard_running() {
    local start=$(date +%s)
    assert_container_running "adguardhome" "AdGuard Home running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "adguard_running" "$?" "$duration" "$STACK_NAME"
}

test_adguard_healthy() {
    local start=$(date +%s)
    assert_container_healthy "adguardhome" 60
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "adguard_healthy" "$?" "$duration" "$STACK_NAME"
}

test_npm_running() {
    local start=$(date +%s)
    assert_container_running "nginx-proxy-manager" "Nginx Proxy Manager running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "npm_running" "$?" "$duration" "$STACK_NAME"
}

test_wireguard_running() {
    local start=$(date +%s)
    assert_container_running "wg-easy" "WireGuard running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "wireguard_running" "$?" "$duration" "$STACK_NAME"
}

test_adguard_control_api() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:3053/control/status" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "adguard_control_api" "$?" "$duration" "$STACK_NAME"
}

test_npm_webui() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:3081" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "npm_webui" "$?" "$duration" "$STACK_NAME"
}

test_wireguard_port() {
    local start=$(date +%s)
    assert_port_open "localhost" 51820 10
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "wireguard_port" "$?" "$duration" "$STACK_NAME"
}

run_network_tests() {
    report_init
    report_stack "Network Stack"

    test_adguard_running
    test_adguard_healthy
    test_npm_running
    test_wireguard_running
    test_adguard_control_api
    test_npm_webui
    test_wireguard_port

    local duration=$(echo "$(date +%s) - $REPORT_START_TIME" | bc)
    report_summary $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
    report_export_json $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_network_tests
fi
