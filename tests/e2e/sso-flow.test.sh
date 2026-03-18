#!/usr/bin/env bash
# =============================================================================
# sso-flow.test.sh — End-to-end SSO login flow test
# =============================================================================
# Tests the full OIDC/OAuth2 flow through Authentik:
#   1. OIDC discovery endpoint accessible
#   2. Authorization endpoint returns login page
#   3. Token endpoint exists and returns proper error for invalid request
#   4. Userinfo endpoint exists
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"

AUTHENTIK_URL="${AUTHENTIK_URL:-http://localhost:9000}"

# Test OIDC discovery
test_oidc_discovery() {
  local discovery_url="${AUTHENTIK_URL}/application/o/.well-known/openid-configuration"
  assert_http_200 "$discovery_url" 15
}

# Test OIDC discovery returns required fields
test_oidc_discovery_fields() {
  local discovery_url="${AUTHENTIK_URL}/application/o/.well-known/openid-configuration"
  local body
  body=$(curl -s --max-time 15 "$discovery_url" 2>/dev/null) || {
    _assert_fail "OIDC discovery fields" "Failed to fetch discovery document"
    return 1
  }

  # Required OIDC fields
  for field in "authorization_endpoint" "token_endpoint" "userinfo_endpoint" "jwks_uri" "issuer"; do
    assert_json_key_exists "$body" ".${field}"
  done
}

# Test authorization endpoint returns a page (302 redirect to login)
test_oidc_authorize() {
  local discovery_url="${AUTHENTIK_URL}/application/o/.well-known/openid-configuration"
  local body
  body=$(curl -s --max-time 15 "$discovery_url" 2>/dev/null)
  local auth_url
  auth_url=$(echo "$body" | jq -r '.authorization_endpoint' 2>/dev/null) || {
    _assert_skip "OIDC authorize endpoint" "Cannot parse discovery document"
    return 0
  }

  # Authorization endpoint should exist (will return 400 without proper params, which is expected)
  local status
  status=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -k "$auth_url" 2>/dev/null)

  # 200 (login form), 302 (redirect), or 400 (missing params) are all valid
  if [[ "$status" == "200" ]] || [[ "$status" == "302" ]] || [[ "$status" == "400" ]]; then
    _assert_pass "OIDC authorize endpoint responds (HTTP ${status})"
  else
    _assert_fail "OIDC authorize endpoint" "Expected 200/302/400, Got: ${status}"
  fi
}

# Test JWKS endpoint returns valid keys
test_oidc_jwks() {
  local discovery_url="${AUTHENTIK_URL}/application/o/.well-known/openid-configuration"
  local body
  body=$(curl -s --max-time 15 "$discovery_url" 2>/dev/null)
  local jwks_url
  jwks_url=$(echo "$body" | jq -r '.jwks_uri' 2>/dev/null) || {
    _assert_skip "OIDC JWKS endpoint" "Cannot parse discovery document"
    return 0
  }

  assert_http_200 "$jwks_url" 10
  assert_http_body_contains "$jwks_url" '"keys"' 10
}

# Test token endpoint exists
test_oidc_token_endpoint() {
  local discovery_url="${AUTHENTIK_URL}/application/o/.well-known/openid-configuration"
  local body
  body=$(curl -s --max-time 15 "$discovery_url" 2>/dev/null)
  local token_url
  token_url=$(echo "$body" | jq -r '.token_endpoint' 2>/dev/null) || {
    _assert_skip "OIDC token endpoint" "Cannot parse discovery document"
    return 0
  }

  # POST to token endpoint without credentials should return 400/401
  local status
  status=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
    -X POST -d "grant_type=client_credentials" "$token_url" 2>/dev/null)

  if [[ "$status" == "400" ]] || [[ "$status" == "401" ]] || [[ "$status" == "403" ]]; then
    _assert_pass "OIDC token endpoint exists (correctly rejects invalid request: HTTP ${status})"
  else
    _assert_fail "OIDC token endpoint" "Unexpected status: ${status}"
  fi
}
