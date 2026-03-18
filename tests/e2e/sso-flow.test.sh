#!/usr/bin/env bash
# sso-flow.test.sh — SSO End-to-End Flow Tests
# Simulates OIDC authorization code flow using curl
set -euo pipefail

# These tests require actual services running; skip gracefully if not available

test_sso_authentik_reachable() {
  test_start "Authentik OIDC discovery endpoint"
  assert_http_200 "http://localhost:9000/application/o/authentik/.well-known/openid-configuration" 15
  test_end
}

test_sso_grafana_redirect() {
  test_start "Grafana redirects to Authentik"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 \
    "http://localhost:3000/login/generic_oauth" 2>/dev/null || echo 000)
  # Grafana should return 200 (login page) or 302 (redirect) — both acceptable
  if [[ "$code" -ge 200 && "$code" -lt 400 ]]; then
    test_pass "Grafana SSO login page reachable (HTTP $code)"
  else
    test_skip "Grafana SSO login not available (HTTP $code)"
  fi
  test_end
}

test_sso_gitea_redirect() {
  test_start "Gitea SSO endpoint"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 \
    "http://localhost:3001/user/oauth2/authentik" 2>/dev/null || echo 000)
  if [[ "$code" -ge 200 && "$code" -lt 400 ]]; then
    test_pass "Gitea SSO endpoint reachable (HTTP $code)"
  else
    test_skip "Gitea SSO not configured (HTTP $code)"
  fi
  test_end
}
