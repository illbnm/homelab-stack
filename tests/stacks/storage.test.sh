#!/usr/bin/env bash
# =============================================================================
# Storage Stack Tests (Nextcloud, MinIO, Filebrowser)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.."; pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/report.sh"

STACK_NAME="storage"
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env" 2>/dev/null || true

test_nextcloud_running() {
    local start=$(date +%s)
    assert_container_running "nextcloud" "Nextcloud running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "nextcloud_running" "$?" "$duration" "$STACK_NAME"
}

test_minio_running() {
    local start=$(date +%s)
    assert_container_running "minio" "MinIO running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "minio_running" "$?" "$duration" "$STACK_NAME"
}

test_filebrowser_running() {
    local start=$(date +%s)
    assert_container_running "filebrowser" "Filebrowser running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "filebrowser_running" "$?" "$duration" "$STACK_NAME"
}

test_nextcloud_status() {
    local start=$(date +%s)
    assert_http_response "http://localhost:8081/status.php" "installed" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "nextcloud_status" "$?" "$duration" "$STACK_NAME"
}

test_minio_console() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:9001" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "minio_console" "$?" "$duration" "$STACK_NAME"
}

test_filebrowser_webui() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:8082" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "filebrowser_webui" "$?" "$duration" "$STACK_NAME"
}

run_storage_tests() {
    report_init
    report_stack "Storage Stack"

    test_nextcloud_running
    test_minio_running
    test_filebrowser_running
    test_nextcloud_status
    test_minio_console
    test_filebrowser_webui

    local duration=$(echo "$(date +%s) - $REPORT_START_TIME" | bc)
    report_summary $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
    report_export_json $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_storage_tests
fi
