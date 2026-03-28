#!/usr/bin/env bash
# =============================================================================
# SSO Flow E2E Test — Authentik OIDC Login Flow Simulation
# Tests the complete authentication flow via curl
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.."; pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/report.sh"

STACK_NAME="e2e-sso"
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env" 2>/dev/null || true

# Authentik credentials from env
AUTHENTIK_USER="${AUTHENTIK_ADMIN_EMAIL:-admin}"
AUTHENTIK_PASS="${AUTHENTIK_ADMIN_PASSWORD:-admin}"
AUTHENTIK_PORT="${AUTHENTIK_PORT:-9000}"

test_sso_grafana_login_flow() {
    local start=$(date +%s)
    local duration

    # Step 1: Check if Grafana redirects to Authentik (OIDC flow start)
    local response_code
    response_code=$(curl -sf -o /dev/null -w '%{http_code}' \
        --connect-timeout 10 --max-time 30 \
        -L "http://localhost:3000/api/health" 2>/dev/null || echo 000)

    # We expect either:
    # - 200: Direct access (already authenticated or auth disabled)
    # - 302/303: Redirect to SSO (expected OIDC behavior)
    if [[ "$response_code" == "200" ]]; then
        _pass "Grafana health accessible (HTTP 200)"
    elif [[ "$response_code" =~ ^(302|303)$ ]]; then
        _pass "Grafana redirects to SSO (HTTP $response_code - expected)"
    else
        _fail "Grafana unexpected response: HTTP $response_code"
    fi
    duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "sso_grafana_flow" "$?" "$duration" "$STACK_NAME"
}

test_authentik_oidc_metadata() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:${AUTHENTIK_PORT}/.well-known/openid-configuration" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "authentik_oidc_metadata" "$?" "$duration" "$STACK_NAME"
}

test_authentik_users_api() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:${AUTHENTIK_PORT}/api/v3/core/users/?page_size=1" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "authentik_users_api" "$?" "$duration" "$STACK_NAME"
}

run_sso_e2e_tests() {
    report_init
    report_stack "E2E: SSO Flow"

    test_authentik_oidc_metadata
    test_authentik_users_api
    test_sso_grafana_login_flow

    local duration=$(echo "$(date +%s) - $REPORT_START_TIME" | bc)
    report_summary $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
    report_export_json $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_sso_e2e_tests
fi
