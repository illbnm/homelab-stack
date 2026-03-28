#!/usr/bin/env bash
# =============================================================================
# Media Stack Tests (Jellyfin, Sonarr, Radarr, qBittorrent)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.."; pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/report.sh"

STACK_NAME="media"
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Container Tests
# ---------------------------------------------------------------------------

test_jellyfin_running() {
    local start=$(date +%s)
    assert_container_running "jellyfin" "Jellyfin running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "jellyfin_running" "$?" "$duration" "$STACK_NAME"
}

test_jellyfin_healthy() {
    local start=$(date +%s)
    assert_container_healthy "jellyfin" 60
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "jellyfin_healthy" "$?" "$duration" "$STACK_NAME"
}

test_sonarr_running() {
    local start=$(date +%s)
    assert_container_running "sonarr" "Sonarr running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "sonarr_running" "$?" "$duration" "$STACK_NAME"
}

test_radarr_running() {
    local start=$(date +%s)
    assert_container_running "radarr" "Radarr running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "radarr_running" "$?" "$duration" "$STACK_NAME"
}

test_qbittorrent_running() {
    local start=$(date +%s)
    assert_container_running "qbittorrent" "qBittorrent running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "qbittorrent_running" "$?" "$duration" "$STACK_NAME"
}

# ---------------------------------------------------------------------------
# HTTP Endpoint Tests
# ---------------------------------------------------------------------------

test_jellyfin_health() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:8096/health" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "jellyfin_health" "$?" "$duration" "$STACK_NAME"
}

test_jellyfin_api_system() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:8096/System/Info" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "jellyfin_api_system" "$?" "$duration" "$STACK_NAME"
}

test_sonarr_api() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:8989/api/v3/system/status" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "sonarr_api" "$?" "$duration" "$STACK_NAME"
}

test_radarr_api() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:7878/api/v3/system/status" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "radarr_api" "$?" "$duration" "$STACK_NAME"
}

test_qbittorrent_webui() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:8080/" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "qbittorrent_webui" "$?" "$duration" "$STACK_NAME"
}

run_media_tests() {
    report_init
    report_stack "Media Stack"

    test_jellyfin_running
    test_jellyfin_healthy
    test_sonarr_running
    test_radarr_running
    test_qbittorrent_running
    test_jellyfin_health
    test_jellyfin_api_system
    test_sonarr_api
    test_radarr_api
    test_qbittorrent_webui

    local duration=$(echo "$(date +%s) - $REPORT_START_TIME" | bc)
    report_summary $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
    report_export_json $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_media_tests
fi
