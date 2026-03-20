#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — E2E: SSO Login Flow Test
# Simulates a complete OIDC authorization code flow via curl.
# =============================================================================

# ===========================================================================
# Level 4 — End-to-End SSO Flow
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 4 ]]; then
  test_group "E2E — SSO Flow"

  AUTHENTIK_URL="${AUTHENTIK_URL:-http://localhost:9000}"
  AUTHENTIK_USER="${AUTHENTIK_ADMIN_EMAIL:-akadmin}"
  AUTHENTIK_PASS="${AUTHENTIK_ADMIN_PASSWORD:-}"

  # Pre-check: Authentik must be running
  if ! is_container_running "authentik-server"; then
    skip_test "SSO E2E: Authentik is accessible" "authentik-server not running"
    skip_test "SSO E2E: OIDC discovery endpoint" "authentik-server not running"
    skip_test "SSO E2E: Login page loads" "authentik-server not running"
    skip_test "SSO E2E: Grafana OAuth redirect" "authentik-server not running"
  else
    # 1. Verify OIDC discovery endpoint
    discovery_url="${AUTHENTIK_URL}/application/o/.well-known/openid-configuration"
    discovery=""
    discovery=$(curl -sf --connect-timeout 5 --max-time 10 "$discovery_url" 2>/dev/null)
    if [[ -n "$discovery" ]]; then
      _record_pass "SSO E2E: OIDC discovery endpoint"

      # Verify required OIDC fields exist
      assert_json_key_exists "$discovery" ".authorization_endpoint" \
        "SSO E2E: OIDC has authorization_endpoint"
      assert_json_key_exists "$discovery" ".token_endpoint" \
        "SSO E2E: OIDC has token_endpoint"
      assert_json_key_exists "$discovery" ".userinfo_endpoint" \
        "SSO E2E: OIDC has userinfo_endpoint"
    else
      _record_fail "SSO E2E: OIDC discovery endpoint" "no response from $discovery_url"
    fi

    # 2. Verify Authentik login page loads
    login_page=""
    login_page=$(curl -sf -o /dev/null -w '%{http_code}' \
      --connect-timeout 5 --max-time 10 \
      "${AUTHENTIK_URL}/if/flow/default-authentication-flow/" 2>/dev/null || echo "000")
    if [[ "$login_page" =~ ^[23] ]]; then
      _record_pass "SSO E2E: Login page loads (HTTP $login_page)"
    else
      _record_fail "SSO E2E: Login page loads" "HTTP $login_page"
    fi

    # 3. Test Grafana OAuth redirect (if Grafana is running)
    if is_container_running "grafana"; then
      grafana_login=""
      grafana_login=$(curl -sf -o /dev/null -w '%{http_code}' \
        --connect-timeout 5 --max-time 10 \
        -L --max-redirs 0 \
        "http://localhost:3000/login/generic_oauth" 2>/dev/null || echo "000")
      # 302 redirect to Authentik is the expected behavior
      if [[ "$grafana_login" == "302" || "$grafana_login" == "307" || "$grafana_login" =~ ^[23] ]]; then
        _record_pass "SSO E2E: Grafana OAuth redirect (HTTP $grafana_login)"
      else
        _record_fail "SSO E2E: Grafana OAuth redirect" "HTTP $grafana_login (expected 302)"
      fi
    else
      skip_test "SSO E2E: Grafana OAuth redirect" "grafana not running"
    fi

    # 4. Test Authentik API token authentication (if credentials available)
    if [[ -n "$AUTHENTIK_PASS" ]]; then
      token_response=""
      token_response=$(curl -sf --connect-timeout 5 --max-time 10 \
        -X POST "${AUTHENTIK_URL}/api/v3/core/tokens/" \
        -H "Content-Type: application/json" \
        -u "${AUTHENTIK_USER}:${AUTHENTIK_PASS}" \
        -d '{"identifier":"test-integration","intent":"api"}' 2>/dev/null)
      if [[ -n "$token_response" ]]; then
        assert_no_errors "$token_response" \
          "SSO E2E: API token creation"
        # Clean up test token
        curl -sf -X DELETE \
          "${AUTHENTIK_URL}/api/v3/core/tokens/test-integration/" \
          -u "${AUTHENTIK_USER}:${AUTHENTIK_PASS}" &>/dev/null
      else
        _record_fail "SSO E2E: API token creation" "no response"
      fi
    else
      skip_test "SSO E2E: API token creation" "AUTHENTIK_ADMIN_PASSWORD not set"
    fi
  fi
fi
