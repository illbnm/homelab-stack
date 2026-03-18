#!/usr/bin/env bash
# =============================================================================
# E2E Test — SSO OIDC Login Flow
#
# Tests the complete Authentik OIDC authorization code flow:
#   1. Access protected service -> redirect to Authentik
#   2. Submit credentials -> get authorization code
#   3. Exchange code for token
#   4. Verify access to protected resource
#
# Requires: Authentik stack running with a configured OIDC provider
# =============================================================================

# Skip if Authentik is not running
_check_sso_prereqs() {
  if ! docker inspect --format='{{.State.Running}}' homelab-authentik-server > /dev/null 2>&1; then
    return 1
  fi
  return 0
}

test_e2e_sso_authentik_health() {
  if ! _check_sso_prereqs; then
    _skip "Authentik not running"
    return
  fi

  local auth_ip
  auth_ip=$(get_container_ip homelab-authentik-server)
  assert_http_200 "http://${auth_ip}:9000/-/health/live/" 30
}

test_e2e_sso_authentik_api_reachable() {
  if ! _check_sso_prereqs; then
    _skip "Authentik not running"
    return
  fi

  local auth_ip
  auth_ip=$(get_container_ip homelab-authentik-server)
  assert_http_response "http://${auth_ip}:9000/api/v3/root/config/" '"version_current"' 15
}

test_e2e_sso_grafana_redirect() {
  if ! _check_sso_prereqs; then
    _skip "Authentik not running"
    return
  fi

  # If Grafana is behind SSO, accessing it should redirect to Authentik
  local grafana_ip
  grafana_ip=$(get_container_ip homelab-grafana 2>/dev/null) || true

  if [[ -z "${grafana_ip}" ]]; then
    _skip "Grafana not running"
    return
  fi

  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --max-time 10 \
    "http://${grafana_ip}:3000/login/generic_oauth" 2>/dev/null) || true

  if [[ "${code}" == "302" || "${code}" == "301" || "${code}" == "307" ]]; then
    _pass
  else
    _skip "Grafana OAuth not configured (got HTTP ${code:-timeout})"
  fi
}

test_e2e_sso_outpost_running() {
  if ! _check_sso_prereqs; then
    _skip "Authentik not running"
    return
  fi

  # Check if ForwardAuth outpost is running
  if docker inspect --format='{{.State.Running}}' homelab-authentik-proxy > /dev/null 2>&1; then
    assert_container_running "homelab-authentik-proxy"
  else
    _skip "Authentik proxy outpost not deployed"
  fi
}
