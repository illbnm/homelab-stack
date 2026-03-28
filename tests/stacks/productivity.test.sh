#!/usr/bin/env bash
# =============================================================================
# Productivity Stack Tests (Gitea, Vaultwarden)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.."; pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/report.sh"

STACK_NAME="productivity"
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env" 2>/dev/null || true

test_gitea_running() {
    local start=$(date +%s)
    assert_container_running "gitea" "Gitea running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "gitea_running" "$?" "$duration" "$STACK_NAME"
}

test_vaultwarden_running() {
    local start=$(date +%s)
    assert_container_running "vaultwarden" "Vaultwarden running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "vaultwarden_running" "$?" "$duration" "$STACK_NAME"
}

test_gitea_api_version() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:3001/api/v1/version" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "gitea_api_version" "$?" "$duration" "$STACK_NAME"
}

test_vaultwarden_webui() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:8080" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "vaultwarden_webui" "$?" "$duration" "$STACK_NAME"
}

run_productivity_tests() {
    report_init
    report_stack "Productivity Stack"

    test_gitea_running
    test_vaultwarden_running
    test_gitea_api_version
    test_vaultwarden_webui

    local duration=$(echo "$(date +%s) - $REPORT_START_TIME" | bc)
    report_summary $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
    report_export_json $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_productivity_tests
fi
