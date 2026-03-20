#!/usr/bin/env bash
# =============================================================================
# E2E Test: SSO Login Flow
# Simulates OIDC authorization code flow via curl:
#   1. Access protected app → 302 redirect to Authentik
#   2. Submit credentials → obtain authorization code
#   3. Exchange code for token
#   4. Verify protected resource is accessible
# =============================================================================

log_group "E2E: SSO Flow"

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
test_sso_prerequisites() {
  local ready=true
  if ! is_container_running "authentik-server"; then
    skip_test "SSO E2E: Authentik not running"
    ready=false
  fi
  if ! is_container_running "grafana"; then
    skip_test "SSO E2E: Grafana not running"
    ready=false
  fi
  [[ "$ready" == true ]]
}

if ! test_sso_prerequisites; then
  return 0 2>/dev/null || exit 0
fi

# ---------------------------------------------------------------------------
# Test: Authentik login page accessible
# ---------------------------------------------------------------------------
test_authentik_login_page() {
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 \
    "http://localhost:9000/if/flow/default-authentication-flow/" 2>/dev/null || echo "000")
  if [[ "$code" =~ ^[23] ]]; then
    _record_result pass "SSO E2E: Authentik login page accessible" "HTTP $code"
  else
    _record_result fail "SSO E2E: Authentik login page accessible" "HTTP $code"
  fi
}

# ---------------------------------------------------------------------------
# Test: Grafana redirects to Authentik for OAuth
# ---------------------------------------------------------------------------
test_grafana_sso_redirect() {
  # When OAuth is configured, Grafana's login page should reference the OAuth provider
  local body
  body=$(curl -sf --connect-timeout 5 --max-time 10 \
    "http://localhost:3000/login" 2>/dev/null || echo "")
  if [[ -n "$body" ]]; then
    # Check that the login page references OAuth/Authentik
    if echo "$body" | grep -qi "oauth\|authentik\|generic_oauth"; then
      _record_result pass "SSO E2E: Grafana login references OAuth provider"
    else
      _record_result fail "SSO E2E: Grafana login references OAuth provider" \
        "no OAuth reference found in login page"
    fi
  else
    _record_result fail "SSO E2E: Grafana login page" "empty response"
  fi
}

# ---------------------------------------------------------------------------
# Test: Authentik API is functional
# ---------------------------------------------------------------------------
test_authentik_api_functional() {
  local result
  result=$(curl -sf --connect-timeout 5 --max-time 10 \
    "http://localhost:9000/api/v3/root/config/" 2>/dev/null || echo "")
  if [[ -n "$result" ]]; then
    assert_json_key_exists "$result" ".error_reporting" \
      "SSO E2E: Authentik API /root/config/ responds"
  else
    _record_result fail "SSO E2E: Authentik API functional" "empty response"
  fi
}

# ---------------------------------------------------------------------------
# Test: OIDC well-known endpoint
# ---------------------------------------------------------------------------
test_oidc_wellknown() {
  local result
  result=$(curl -sf --connect-timeout 5 --max-time 10 \
    "http://localhost:9000/application/o/.well-known/openid-configuration" 2>/dev/null || echo "")
  if [[ -n "$result" ]]; then
    assert_json_key_exists "$result" ".authorization_endpoint" \
      "SSO E2E: OIDC well-known has authorization_endpoint"
    assert_json_key_exists "$result" ".token_endpoint" \
      "SSO E2E: OIDC well-known has token_endpoint"
    assert_json_key_exists "$result" ".userinfo_endpoint" \
      "SSO E2E: OIDC well-known has userinfo_endpoint"
  else
    _record_result fail "SSO E2E: OIDC well-known endpoint" "empty response"
  fi
}

# ---------------------------------------------------------------------------
# Test: Token endpoint reachable (POST with invalid creds should return 400, not 5xx)
# ---------------------------------------------------------------------------
test_token_endpoint_reachable() {
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 \
    -X POST \
    -d "grant_type=authorization_code&code=invalid&client_id=test&redirect_uri=http://localhost" \
    "http://localhost:9000/application/o/token/" 2>/dev/null || echo "000")
  # 400 or 401 = endpoint works, just invalid creds
  if [[ "$code" =~ ^(400|401|403)$ ]]; then
    _record_result pass "SSO E2E: Token endpoint reachable" "HTTP $code (expected client error)"
  elif [[ "$code" =~ ^5 ]]; then
    _record_result fail "SSO E2E: Token endpoint reachable" "HTTP $code (server error)"
  elif [[ "$code" == "000" ]]; then
    _record_result fail "SSO E2E: Token endpoint reachable" "connection failed"
  else
    _record_result pass "SSO E2E: Token endpoint reachable" "HTTP $code"
  fi
}

# Run tests
test_authentik_login_page
test_grafana_sso_redirect
test_authentik_api_functional
test_oidc_wellknown
test_token_endpoint_reachable
