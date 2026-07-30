#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# E2E: SSO Login Flow — Full OIDC Authorization Code Flow
# ════════════════════════════════════════════════════════════════

test_sso_discovery() {
  local domain="${DOMAIN:-localhost}"
  local authentik_url="${AUTHENTIK_URL:-http://localhost:9000}"
  local result
  result=$(curl -s "${authentik_url}/.well-known/openid-configuration" 2>/dev/null || echo "")
  assert_json_key_exists "$result" ".issuer" "OIDC discovery should return issuer"
  assert_json_key_exists "$result" ".authorization_endpoint" "Discovery should have auth endpoint"
  assert_json_key_exists "$result" ".token_endpoint" "Discovery should have token endpoint"
  assert_json_key_exists "$result" ".userinfo_endpoint" "Discovery should have userinfo endpoint"
}

test_sso_grafana_login_redirect() {
  local domain="${DOMAIN:-localhost}"
  local grafana_url="${GRAFANA_URL:-http://localhost:3000}"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${grafana_url}/login/generic_oauth" 2>/dev/null || echo "000")
  # Should redirect (302) to Authentik or show login page (200)
  if [[ "$code" == "302" || "$code" == "200" ]]; then
    return 0
  fi
  return 1
}

test_sso_authorization_endpoint() {
  local authentik_url="${AUTHENTIK_URL:-http://localhost:9000}"
  local client_id="${GRAFANA_OIDC_CLIENT_ID:-test}"
  local redirect_uri="${GRAFANA_REDIRECT_URI:-http://localhost:3000/login/generic_oauth}"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    "${authentik_url}/application/o/authorize/?client_id=${client_id}&redirect_uri=${redirect_uri}&response_type=code&scope=openid+profile+email" 2>/dev/null || echo "000")
  # Should return 200 (login page) or 302 (redirect)
  if [[ "$code" == "200" || "$code" == "302" ]]; then
    return 0
  fi
  return 1
}

test_sso_token_endpoint() {
  local authentik_url="${AUTHENTIK_URL:-http://localhost:9000}"
  local result
  result=$(curl -s -X POST "${authentik_url}/application/o/token/" \
    -d "grant_type=invalid" -d "client_id=test" 2>/dev/null || echo "")
  # Should return an error (invalid_grant) but NOT a connection error
  assert_contains "$result" "error" "Token endpoint should respond with error for invalid grant"
}

test_sso_userinfo_endpoint() {
  local authentik_url="${AUTHENTIK_URL:-http://localhost:9000}"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    -H "Authorization: Bearer invalid-token" \
    "${authentik_url}/application/o/userinfo/" 2>/dev/null || echo "000")
  # Should return 401 for invalid token
  assert_eq "$code" "401" "UserInfo endpoint should reject invalid tokens"
}

test_sso_forwardauth() {
  local authentik_url="${AUTHENTIK_URL:-http://localhost:9000}"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    "${authentik_url}/outpost.goauthentik.io/auth/traefik" 2>/dev/null || echo "000")
  # Should return 401 (not authenticated) or 200 (if no auth required)
  if [[ "$code" == "401" || "$code" == "200" ]]; then
    return 0
  fi
  return 1
}

test_sso_groups_created() {
  local authentik_url="${AUTHENTIK_URL:-http://localhost:9000}"
  local token="${AUTHENTIK_TOKEN:-}"
  if [[ -z "$token" ]]; then return 1; fi
  local result
  result=$(curl -s -H "Authorization: Bearer ${token}" \
    "${authentik_url}/api/v3/core/groups/" 2>/dev/null || echo "[]")
  assert_contains "$result" "homelab" "Authentik should have homelab groups"
}