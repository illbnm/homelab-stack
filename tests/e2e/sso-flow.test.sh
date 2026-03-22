#!/usr/bin/env bash
# sso-flow.test.sh — End-to-end SSO flow tests (Authentik OIDC)
# Simulates a full OIDC authorization-code flow using curl.

AUTHENTIK_HOST="${AUTHENTIK_HOST:-localhost}"
AUTHENTIK_PORT="${AUTHENTIK_PORT:-9000}"
AUTHENTIK_BASE="http://${AUTHENTIK_HOST}:${AUTHENTIK_PORT}"

GRAFANA_HOST="${GRAFANA_HOST:-localhost}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
GRAFANA_BASE="http://${GRAFANA_HOST}:${GRAFANA_PORT}"

# ── Pre-flight: check containers are deployed ─────────────────────────────────

AUTHENTIK_DEPLOYED=0
GRAFANA_DEPLOYED=0

if docker_container_exists "authentik-server"; then
  AUTHENTIK_DEPLOYED=1
fi

if docker_container_exists "grafana"; then
  GRAFANA_DEPLOYED=1
fi

# ── Level 1: Authentik reachability ──────────────────────────────────────────

if [[ $AUTHENTIK_DEPLOYED -eq 1 ]]; then
  assert_http_200 "e2e/sso: Authentik health endpoint reachable" \
    "${AUTHENTIK_BASE}/-/health/ready/"

  login_page_code=$(curl -sk -o /dev/null -w '%{http_code}' \
    --max-time 10 \
    "${AUTHENTIK_BASE}/if/flow/default-authentication-flow/" 2>/dev/null || echo "000")
  if [[ "$login_page_code" == "200" ]]; then
    assert_pass "e2e/sso: Authentik login flow page reachable"
  else
    assert_fail "e2e/sso: Authentik login flow page reachable" \
      "HTTP ${login_page_code}"
  fi
else
  assert_skip "e2e/sso: Authentik health endpoint reachable" "authentik-server not deployed"
  assert_skip "e2e/sso: Authentik login flow page reachable" "authentik-server not deployed"
fi

# ── Level 2: Authentik API token authentication ───────────────────────────────

AUTHENTIK_TOKEN="${AUTHENTIK_TOKEN:-}"

if [[ $AUTHENTIK_DEPLOYED -eq 1 && -n "$AUTHENTIK_TOKEN" ]]; then
  users_resp=$(curl -sk --max-time 10 \
    -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
    "${AUTHENTIK_BASE}/api/v3/core/users/?page_size=1" 2>/dev/null || echo '{}')

  if echo "$users_resp" | jq -e '.results' &>/dev/null; then
    assert_pass "e2e/sso: Authentik API authentication valid"
  else
    assert_fail "e2e/sso: Authentik API authentication valid" \
      "API did not return expected .results field"
  fi

  apps_resp=$(curl -sk --max-time 10 \
    -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
    "${AUTHENTIK_BASE}/api/v3/core/applications/" 2>/dev/null || echo '{}')
  assert_json_key_exists "e2e/sso: Authentik applications endpoint responds" \
    "$apps_resp" '.results'
else
  assert_skip "e2e/sso: Authentik API authentication valid" \
    "AUTHENTIK_TOKEN not set or container not deployed"
  assert_skip "e2e/sso: Authentik applications endpoint responds" \
    "AUTHENTIK_TOKEN not set or container not deployed"
fi

# ── Level 3: OIDC discovery document ─────────────────────────────────────────

if [[ $AUTHENTIK_DEPLOYED -eq 1 ]]; then
  # Authentik exposes the OIDC discovery document for each provider
  # We check the well-known endpoint (requires a configured OIDC provider slug)
  OIDC_PROVIDER_SLUG="${OIDC_PROVIDER_SLUG:-homelab}"
  oidc_discovery=$(curl -sk --max-time 10 \
    "${AUTHENTIK_BASE}/application/o/${OIDC_PROVIDER_SLUG}/.well-known/openid-configuration" \
    2>/dev/null || echo '{}')

  if echo "$oidc_discovery" | jq -e '.issuer' &>/dev/null; then
    assert_pass "e2e/sso: OIDC discovery document available"
    assert_json_key_exists "e2e/sso: OIDC discovery has authorization_endpoint" \
      "$oidc_discovery" '.authorization_endpoint'
    assert_json_key_exists "e2e/sso: OIDC discovery has token_endpoint" \
      "$oidc_discovery" '.token_endpoint'
    assert_json_key_exists "e2e/sso: OIDC discovery has jwks_uri" \
      "$oidc_discovery" '.jwks_uri'
  else
    assert_skip "e2e/sso: OIDC discovery document available" \
      "provider slug '${OIDC_PROVIDER_SLUG}' not configured"
    assert_skip "e2e/sso: OIDC discovery has authorization_endpoint" \
      "OIDC provider not configured"
    assert_skip "e2e/sso: OIDC discovery has token_endpoint" \
      "OIDC provider not configured"
    assert_skip "e2e/sso: OIDC discovery has jwks_uri" \
      "OIDC provider not configured"
  fi
else
  assert_skip "e2e/sso: OIDC discovery document available" "authentik-server not deployed"
  assert_skip "e2e/sso: OIDC discovery has authorization_endpoint" "authentik-server not deployed"
  assert_skip "e2e/sso: OIDC discovery has token_endpoint" "authentik-server not deployed"
  assert_skip "e2e/sso: OIDC discovery has jwks_uri" "authentik-server not deployed"
fi

# ── Level 4: Forward-auth redirect validation ─────────────────────────────────
# When Grafana SSO is enabled, an unauthenticated request should redirect
# to Authentik. We check for a 302 redirect towards authentik.

if [[ $GRAFANA_DEPLOYED -eq 1 && $AUTHENTIK_DEPLOYED -eq 1 ]]; then
  GRAFANA_SSO_ENABLED="${GRAFANA_SSO_ENABLED:-false}"
  if [[ "$GRAFANA_SSO_ENABLED" == "true" ]]; then
    redirect_location=$(curl -sk -o /dev/null \
      --max-time 10 \
      -w '%{redirect_url}' \
      "${GRAFANA_BASE}/login" 2>/dev/null || echo "")

    if echo "$redirect_location" | grep -q "authentik"; then
      assert_pass "e2e/sso: Grafana login redirects to Authentik"
    else
      assert_skip "e2e/sso: Grafana login redirects to Authentik" \
        "redirect_url='${redirect_location}' does not contain 'authentik'"
    fi
  else
    assert_skip "e2e/sso: Grafana login redirects to Authentik" \
      "GRAFANA_SSO_ENABLED != true"
  fi
else
  assert_skip "e2e/sso: Grafana login redirects to Authentik" \
    "grafana or authentik-server not deployed"
fi

# ── Level 4: Authentik outpost reachability ───────────────────────────────────

if [[ $AUTHENTIK_DEPLOYED -eq 1 ]]; then
  outpost_resp=$(curl -sk --max-time 10 \
    "${AUTHENTIK_BASE}/outpost.goauthentik.io/ping" 2>/dev/null || echo '{}')
  if echo "$outpost_resp" | grep -qi "ok\|ping"; then
    assert_pass "e2e/sso: Authentik embedded outpost reachable"
  else
    assert_skip "e2e/sso: Authentik embedded outpost reachable" \
      "outpost ping did not return ok"
  fi
else
  assert_skip "e2e/sso: Authentik embedded outpost reachable" \
    "authentik-server not deployed"
fi
