#!/usr/bin/env bash
# =============================================================================
# AI Stack Tests (Ollama, Open WebUI)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.."; pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/report.sh"

STACK_NAME="ai"
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env" 2>/dev/null || true

test_ollama_running() {
    local start=$(date +%s)
    assert_container_running "ollama" "Ollama running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "ollama_running" "$?" "$duration" "$STACK_NAME"
}

test_open_webui_running() {
    local start=$(date +%s)
    assert_container_running "open-webui" "Open WebUI running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "open_webui_running" "$?" "$duration" "$STACK_NAME"
}

test_ollama_api_version() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:11434/api/version" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "ollama_api_version" "$?" "$duration" "$STACK_NAME"
}

test_ollama_tags_endpoint() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:11434/api/tags" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "ollama_tags" "$?" "$duration" "$STACK_NAME"
}

test_open_webui_webui() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:3080" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "open_webui_webui" "$?" "$duration" "$STACK_NAME"
}

run_ai_tests() {
    report_init
    report_stack "AI Stack"

    test_ollama_running
    test_open_webui_running
    test_ollama_api_version
    test_ollama_tags_endpoint
    test_open_webui_webui

    local duration=$(echo "$(date +%s) - $REPORT_START_TIME" | bc)
    report_summary $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
    report_export_json $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_ai_tests
fi
