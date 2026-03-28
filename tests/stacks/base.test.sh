#!/usr/bin/env bash
# =============================================================================
# Base Infrastructure Stack Tests
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.."; pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/report.sh"

STACK_NAME="base"
COMPOSE_FILE="$BASE_DIR/stacks/base/docker-compose.yml"

# Source env if exists
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env" 2>/dev/null || true

# Use domain from env or fallback
DOMAIN="${DOMAIN:-localhost}"

# ---------------------------------------------------------------------------
# Container Health Tests (Level 1)
# ---------------------------------------------------------------------------

test_traefik_running() {
    local start=$(date +%s)
    assert_container_running "traefik" "Traefik container running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "traefik_running" "$?" "$duration" "$STACK_NAME"
}

test_traefik_healthy() {
    local start=$(date +%s)
    assert_container_healthy "traefik" 60
    report_add_result "traefik_healthy" "$?" "$duration" "$STACK_NAME"
}

test_portainer_running() {
    local start=$(date +%s)
    assert_container_running "portainer" "Portainer container running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "portainer_running" "$?" "$duration" "$STACK_NAME"
}

test_portainer_healthy() {
    local start=$(date +%s)
    assert_container_healthy "portainer" 60
    report_add_result "portainer_healthy" "$?" "$duration" "$STACK_NAME"
}

test_watchtower_running() {
    local start=$(date +%s)
    assert_container_running "watchtower" "Watchtower container running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "watchtower_running" "$?" "$duration" "$STACK_NAME"
}

# ---------------------------------------------------------------------------
# HTTP Endpoint Tests (Level 2)
# ---------------------------------------------------------------------------

test_traefik_api_version() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:80/api/version" 15
    report_add_result "traefik_api_version" "$?" "$duration" "$STACK_NAME"
}

test_portainer_api_status() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:9000/api/status" 15
    report_add_result "portainer_api_status" "$?" "$duration" "$STACK_NAME"
}

# ---------------------------------------------------------------------------
# Configuration Tests (Level 1)
# ---------------------------------------------------------------------------

test_compose_syntax() {
    local start=$(date +%s)
    if [[ -f "$COMPOSE_FILE" ]]; then
        docker compose -f "$COMPOSE_FILE" config --quiet 2>/dev/null
        assert_eq "$?" "0" "Base compose config valid"
    else
        _skip "Compose file not found"
    fi
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "compose_syntax" "$?" "$duration" "$STACK_NAME"
}

test_no_latest_tags() {
    local start=$(date +%s)
    assert_no_latest_images "$BASE_DIR/stacks/base" "No :latest tags in base stack"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "no_latest_tags" "$?" "$duration" "$STACK_NAME"
}

test_traefik_config_exists() {
    local start=$(date +%s)
    assert_file_exists "$BASE_DIR/config/traefik/traefik.yml" "Traefik config exists"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "traefik_config_exists" "$?" "$duration" "$STACK_NAME"
}

# ---------------------------------------------------------------------------
# Run all base tests
# ---------------------------------------------------------------------------

run_base_tests() {
    report_init
    report_stack "Base Infrastructure"

    test_traefik_running
    test_traefik_healthy
    test_portainer_running
    test_portainer_healthy
    test_watchtower_running
    test_traefik_api_version
    test_portainer_api_status
    test_compose_syntax
    test_no_latest_tags
    test_traefik_config_exists

    local duration=$(echo "$(date +%s) - $REPORT_START_TIME" | bc)
    report_summary $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
    report_export_json $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_base_tests
fi
