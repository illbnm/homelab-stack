#!/usr/bin/env bash
# =============================================================================
# SSO Stack Tests (Authentik)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.."; pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/report.sh"

STACK_NAME="sso"
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Container Tests
# ---------------------------------------------------------------------------

test_authentik_server_running() {
    local start=$(date +%s)
    assert_container_running "authentik-server" "Authentik server running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "authentik_server_running" "$?" "$duration" "$STACK_NAME"
}

test_authentik_worker_running() {
    local start=$(date +%s)
    assert_container_running "authentik-worker" "Authentik worker running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "authentik_worker_running" "$?" "$duration" "$STACK_NAME"
}

test_authentik_postgres_running() {
    local start=$(date +%s)
    assert_container_running "authentik-postgresql" "Authentik PostgreSQL running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "authentik_postgres_running" "$?" "$duration" "$STACK_NAME"
}

test_authentik_redis_running() {
    local start=$(date +%s)
    assert_container_running "authentik-redis" "Authentik Redis running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "authentik_redis_running" "$?" "$duration" "$STACK_NAME"
}

test_authentik_server_healthy() {
    local start=$(date +%s)
    assert_container_healthy "authentik-server" 120
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "authentik_server_healthy" "$?" "$duration" "$STACK_NAME"
}

# ---------------------------------------------------------------------------
# HTTP Endpoint Tests
# ---------------------------------------------------------------------------

test_authentik_api_users() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:9000/api/v3/core/users/?page_size=1" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "authentik_api_users" "$?" "$duration" "$STACK_NAME"
}

test_authentik_outpost_api() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:9000/api/v3/outposts/" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "authentik_outpost_api" "$?" "$duration" "$STACK_NAME"
}

run_sso_tests() {
    report_init
    report_stack "SSO (Authentik)"

    test_authentik_server_running
    test_authentik_worker_running
    test_authentik_postgres_running
    test_authentik_redis_running
    test_authentik_server_healthy
    test_authentik_api_users
    test_authentik_outpost_api

    local duration=$(echo "$(date +%s) - $REPORT_START_TIME" | bc)
    report_summary $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
    report_export_json $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_sso_tests
fi
