#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Base Infrastructure Tests
# =============================================================================
# Tests: Traefik, Portainer, Watchtower
# Level 1: Container health + Level 2: HTTP endpoints
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1 — Container Health
# ---------------------------------------------------------------------------

test_traefik_running() {
  assert_container_running "traefik"
}

test_traefik_healthy() {
  assert_container_healthy "traefik" 60
}

test_portainer_running() {
  assert_container_running "portainer"
}

test_portainer_healthy() {
  assert_container_healthy "portainer" 60
}

test_watchtower_running() {
  assert_container_running "watchtower"
}

# ---------------------------------------------------------------------------
# Level 2 — HTTP Endpoints
# ---------------------------------------------------------------------------

test_traefik_api_version() {
  assert_http_200 "http://localhost:8080/api/version" 30
}

test_traefik_dashboard() {
  assert_http_200 "http://localhost:8080/dashboard/" 30
}

test_portainer_api_status() {
  assert_http_200 "http://localhost:9000/api/status" 30
}

# ---------------------------------------------------------------------------
# Level 1 — Network Isolation
# ---------------------------------------------------------------------------

test_traefik_on_proxy_network() {
  assert_container_on_network "traefik" "proxy"
}

test_portainer_on_proxy_network() {
  assert_container_on_network "portainer" "proxy"
}

# ---------------------------------------------------------------------------
# Level 1 — Configuration
# ---------------------------------------------------------------------------

test_base_compose_valid() {
  local compose_file="${PROJECT_ROOT}/stacks/base/docker-compose.yml"

  if [[ ! -f "${compose_file}" ]]; then
    _assert_skip "Base compose file not found"
    return 0
  fi

  assert_compose_valid "${compose_file}"
}

test_traefik_acme_exists() {
  local acme_file="${PROJECT_ROOT}/config/traefik/acme.json"

  if [[ -f "${acme_file}" ]]; then
    # Verify permissions (should be 600)
    local perms
    perms=$(stat -c '%a' "${acme_file}" 2>/dev/null || stat -f '%Lp' "${acme_file}" 2>/dev/null || echo "unknown")
    if [[ "${perms}" == "600" ]]; then
      _assert_pass "acme.json exists with correct permissions (600)"
    else
      _assert_fail "acme.json has permissions ${perms}, expected 600"
    fi
  else
    _assert_skip "acme.json not found (may not be created yet)"
  fi
}
