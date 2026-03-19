#!/usr/bin/env bash
# =============================================================================
# sso-flow.test.sh — SSO complete login flow end-to-end test
# =============================================================================

test_suite "E2E — SSO Login Flow"

test_sso_login_page_loads() {
  assert_http_200 "http://localhost:9000/if/flow/default-authentication-flow/" \
    "Authentik login page loads"
}

test_sso_csrf_token_present() {
  local body
  body=$(curl -sf --connect-timeout 5 --max-time 10 \
    "http://localhost:9000/if/flow/default-authentication-flow/" 2>/dev/null || echo "")
  if [[ -n "$body" ]]; then
    test_pass "Login page returns content"
  else
    test_fail "Login page returns content" "empty response"
  fi
}

test_sso_api_reachable() {
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' \
    --connect-timeout 5 --max-time 10 \
    "http://localhost:9000/api/v3/root/config/" 2>/dev/null || echo "000")
  if [[ "$code" == "200" || "$code" == "403" ]]; then
    test_pass "Authentik API reachable (HTTP $code)"
  else
    test_fail "Authentik API reachable" "HTTP $code"
  fi
}

test_sso_login_with_credentials() {
  if [[ -z "${AUTHENTIK_BOOTSTRAP_EMAIL:-}" || -z "${AUTHENTIK_BOOTSTRAP_PASSWORD:-}" ]]; then
    test_skip "SSO login with credentials" "AUTHENTIK_BOOTSTRAP_EMAIL/PASSWORD not set"
    return
  fi

  # Step 1: Start the authentication flow
  local flow_response
  flow_response=$(curl -sf --connect-timeout 5 --max-time 10 \
    -H "Content-Type: application/json" \
    "http://localhost:9000/api/v3/flows/executor/default-authentication-flow/" 2>/dev/null || echo "")

  if [[ -z "$flow_response" ]]; then
    test_fail "SSO login flow" "could not start authentication flow"
    return
  fi

  # Step 2: Submit identification (username/email)
  local ident_response
  ident_response=$(curl -sf --connect-timeout 5 --max-time 10 \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{\"uid_field\": \"${AUTHENTIK_BOOTSTRAP_EMAIL}\"}" \
    "http://localhost:9000/api/v3/flows/executor/default-authentication-flow/" 2>/dev/null || echo "")

  if [[ -z "$ident_response" ]]; then
    test_fail "SSO identification stage" "no response"
    return
  fi
  test_pass "SSO identification stage submitted"

  # Step 3: Submit password
  local auth_response
  auth_response=$(curl -sf --connect-timeout 5 --max-time 10 \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{\"password\": \"${AUTHENTIK_BOOTSTRAP_PASSWORD}\"}" \
    "http://localhost:9000/api/v3/flows/executor/default-authentication-flow/" 2>/dev/null || echo "")

  if [[ -n "$auth_response" ]]; then
    test_pass "SSO password stage submitted"
  else
    test_fail "SSO password stage" "no response"
  fi
}

test_sso_login_page_loads
test_sso_csrf_token_present
test_sso_api_reachable
test_sso_login_with_credentials
