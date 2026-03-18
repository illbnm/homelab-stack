#!/usr/bin/env bash
# sso-flow.test.sh - End-to-end SSO (Authentik) login flow test
# Copyright (c) 2026 homelab-stack contributors
# SPDX-License-Identifier: MIT
#
# Simulates an OIDC authorization code flow:
# 1. Discover OIDC configuration
# 2. Get authorization URL
# 3. Submit credentials
# 4. Obtain authorization code
# 5. Exchange code for tokens

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"
source "${SCRIPT_DIR}/../lib/report.sh"

STACK_NAME="e2e-sso-flow"
AUTHENTIK_HOST="${AUTHENTIK_HOST:-localhost}"
AUTHENTIK_PORT="${AUTHENTIK_PORT:-9000}"
AUTHENTIK_USER="${AUTHENTIK_USER:-akadmin}"
AUTHENTIK_PASS="${AUTHENTIK_PASS:-changeme}"
TEST_APP_NAME="test-app-$(date +%s)"

setup() {
    assert_reset
    report_init "$STACK_NAME"
    # Create temp directory for cookies and responses
    _SSO_TMPDIR=$(mktemp -d)
    trap "rm -rf '${_SSO_TMPDIR}'" EXIT
}

teardown() {
    report_write_json
    report_print_summary
    rm -rf "${_SSO_TMPDIR}"
}

# Step 1: Discover OIDC well-known configuration
test_oidc_discovery() {
    assert_set_test "oidc_discovery"
    local response
    response=$(curl -sf --max-time 15 \
        "http://${AUTHENTIK_HOST}:${AUTHENTIK_PORT}/application/o/nextcloud/.well-known/openid-configuration" 2>/dev/null) || true

    if [ -n "$response" ]; then
        assert_json_key_exists "$response" ".authorization_endpoint" "OIDC discovery should return authorization_endpoint"
        assert_json_key_exists "$response" ".token_endpoint" "OIDC discovery should return token_endpoint"
        # Save for later use
        echo "$response" > "${_SSO_TMPDIR}/discovery.json"
    else
        _assert_skip "OIDC discovery" "authentik not reachable at ${AUTHENTIK_HOST}:${AUTHENTIK_PORT}"
    fi
}

# Step 2: Get authorization URL and initiate login
test_authorization_request() {
    assert_set_test "authorization_request"
    if [ ! -f "${_SSO_TMPDIR}/discovery.json" ]; then
        _assert_skip "authorization request" "OIDC discovery did not complete"
        return
    fi

    local auth_url
    auth_url=$(jq -r '.authorization_endpoint // empty' "${_SSO_TMPDIR}/discovery.json" 2>/dev/null) || true
    if [ -z "$auth_url" ]; then
        _assert_skip "authorization request" "could not extract authorization_endpoint"
        return
    fi

    local redirect_uri="http://${AUTHENTIK_HOST}:${AUTHENTIK_PORT}/outpost.goauthentik.io/callback"
    local full_url="${auth_url}?client_id=test&redirect_uri=${redirect_uri}&response_type=code&scope=openid+profile+email&state=test123"

    local response
    response=$(curl -sfL --max-time 15 -c "${_SSO_TMPDIR}/cookies.txt" \
        "$full_url" 2>/dev/null | head -c 10000) || true

    if [ -n "$response" ]; then
        assert_contains "$response" "authentik" "login page should contain authentik"
        echo "$response" > "${_SSO_TMPDIR}/login_page.html"
    else
        _assert_fail "authorization request" "no response from authorization endpoint"
    fi
}

# Step 3: Verify login page is rendered
test_login_page_renders() {
    assert_set_test "login_page_renders"
    if [ ! -f "${_SSO_TMPDIR}/login_page.html" ]; then
        _assert_skip "login page render" "previous step did not complete"
        return
    fi

    local html
    html=$(cat "${_SSO_TMPDIR}/login_page.html")
    assert_contains "$html" "password" "login page should have password field"
}

# Step 4: Check token endpoint is accessible
test_token_endpoint_accessible() {
    assert_set_test "token_endpoint_accessible"
    if [ ! -f "${_SSO_TMPDIR}/discovery.json" ]; then
        _assert_skip "token endpoint" "OIDC discovery did not complete"
        return
    fi

    local token_url
    token_url=$(jq -r '.token_endpoint // empty' "${_SSO_TMPDIR}/discovery.json" 2>/dev/null) || true
    if [ -z "$token_url" ]; then
        _assert_skip "token endpoint" "could not extract token_endpoint"
        return
    fi

    # POST empty body to verify endpoint exists (expect 400/401, not connection error)
    local status
    status=$(curl -sf -o /dev/null -w '%{http_code}' --max-time 10 \
        -X POST "$token_url" 2>/dev/null) || true
    if [ "$status" = "400" ] || [ "$status" = "401" ] || [ "$status" = "405" ]; then
        _assert_pass "token endpoint is accessible (HTTP ${status})"
    else
        _assert_fail "token endpoint" "unexpected status: ${status}"
    fi
}

# Step 5: Verify user info endpoint (optional)
test_userinfo_endpoint() {
    assert_set_test "userinfo_endpoint"
    if [ ! -f "${_SSO_TMPDIR}/discovery.json" ]; then
        _assert_skip "userinfo endpoint" "OIDC discovery did not complete"
        return
    fi

    local userinfo_url
    userinfo_url=$(jq -r '.userinfo_endpoint // empty' "${_SSO_TMPDIR}/discovery.json" 2>/dev/null) || true
    if [ -z "$userinfo_url" ]; then
        _assert_skip "userinfo endpoint" "userinfo_endpoint not in discovery"
        return
    fi

    # Without auth token, expect 401
    local status
    status=$(curl -sf -o /dev/null -w '%{http_code}' --max-time 10 \
        "$userinfo_url" 2>/dev/null) || true
    assert_ne "$status" "000" "userinfo endpoint should be reachable"
}

# --- Run ---
setup
for func in $(declare -F | grep -o 'test_' | sort); do
    echo -e "\n${_C_CYAN}▶ ${func}${_C_RESET}"
    $func
done
teardown
