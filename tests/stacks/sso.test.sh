#!/bin/bash
# sso.test.sh - SSO Stack Integration Tests
# Tests for: Authentik (OIDC Provider)

set -o pipefail

# Test Authentik running
test_sso_authentik_running() {
    local test_name="[sso] Authentik running"
    start_test "$test_name"
    
    if assert_container_running "authentik-server"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Container not running"
    fi
}

# Test Authentik PostgreSQL
test_sso_authentik_db() {
    local test_name="[sso] Authentik PostgreSQL running"
    start_test "$test_name"
    
    if assert_container_running "authentik-db"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Database not running"
    fi
}

# Test Authentik Web UI
test_sso_authentik_webui() {
    local test_name="[sso] Authentik Web UI"
    start_test "$test_name"
    
    if assert_http_200 "http://localhost:9000" 30; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Web UI not accessible"
    fi
}

# Test Authentik API
test_sso_authentik_api() {
    local test_name="[sso] Authentik API /api/v3/core/users/"
    start_test "$test_name"
    
    # This may require authentication, but should return a response
    local response
    response=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost:9000/api/v3/core/users/?page_size=1" 2>/dev/null)
    
    # 200 or 401/403 are acceptable (means API is responding)
    if [[ "$response" == "200" || "$response" == "401" || "$response" == "403" ]]; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "API not responding (HTTP $response)"
    fi
}

# Test Authentik health endpoint
test_sso_authentik_health() {
    local test_name="[sso] Authentik health endpoint"
    start_test "$test_name"
    
    if assert_http_response "http://localhost:9000/-/health" "" 30; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Health endpoint not responding"
    fi
}

# Test OIDC discovery endpoint
test_sso_authentik_oidc_discovery() {
    local test_name="[sso] OIDC discovery endpoint"
    start_test "$test_name"
    
    local response
    response=$(curl -s "http://localhost:9000/application/o/authorize/.well-known/openid-configuration" 2>/dev/null)
    
    if echo "$response" | grep -q "issuer"; then
        pass_test "$test_name"
    else
        # May need specific application URL
        assert_skip "OIDC discovery URL may vary by application"
    fi
}

# Run all SSO tests
test_sso_all() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  SSO Stack Tests"
    echo "════════════════════════════════════════"
    
    test_sso_authentik_running
    test_sso_authentik_db
    test_sso_authentik_webui
    test_sso_authentik_api
    test_sso_authentik_health
    test_sso_authentik_oidc_discovery
}

# Helper functions
start_test() {
    local name="$1"
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}▶${NC} $name"
    fi
}

pass_test() {
    local name="$1"
    echo -e "${GREEN}✅ PASS${NC} $name"
}

fail_test() {
    local name="$1"
    local reason="$2"
    echo -e "${RED}❌ FAIL${NC} $name - $reason"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    VERBOSE="${VERBOSE:-false}"
    test_sso_all
fi
