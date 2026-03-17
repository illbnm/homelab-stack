#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — SSO Stack Tests
# =============================================================================
# Tests: Authentik (server + worker), SSO PostgreSQL, SSO Redis
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1 — Container Health
# ---------------------------------------------------------------------------

test_authentik_server_running() {
  assert_container_running "authentik-server"
}

test_authentik_server_healthy() {
  assert_container_healthy "authentik-server" 120
}

test_authentik_worker_running() {
  assert_container_running "authentik-worker"
}

test_authentik_worker_healthy() {
  assert_container_healthy "authentik-worker" 120
}

# ---------------------------------------------------------------------------
# Level 2 — HTTP Endpoints
# ---------------------------------------------------------------------------

test_authentik_api_root() {
  assert_http_200 "http://localhost:9000/api/v3/" 30
}

test_authentik_health_ready() {
  assert_http_200 "http://localhost:9000/-/health/ready/" 30
}

test_authentik_health_live() {
  assert_http_200 "http://localhost:9000/-/health/live/" 30
}

test_authentik_openid_configuration() {
  assert_http_200 "http://localhost:9000/application/o/.well-known/openid-configuration" 30
}

test_authentik_users_endpoint() {
  if [[ -n "${AUTHENTIK_BOOTSTRAP_TOKEN:-}" ]]; then
    local result
    result=$(curl -s -H "Authorization: Bearer ${AUTHENTIK_BOOTSTRAP_TOKEN}" \
      "http://localhost:9000/api/v3/core/users/?page_size=1" 2>/dev/null || echo '{}')
    assert_json_key_exists "${result}" ".results"
  else
    # Try without auth — should still return 200 (or 403 which is fine for auth check)
    assert_http_response "http://localhost:9000/api/v3/core/users/?page_size=1" "" 30 || true
    _assert_skip "AUTHENTIK_BOOTSTRAP_TOKEN not set — skipping authenticated test"
  fi
}

# ---------------------------------------------------------------------------
# Level 3 — Inter-Service Communication
# ---------------------------------------------------------------------------

test_authentik_database_connection() {
  # If Authentik API is responsive, the database connection is working
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' \
    "http://localhost:9000/-/health/ready/" 2>/dev/null || echo "000")

  if [[ "${code}" == "200" || "${code}" == "204" ]]; then
    _assert_pass "Authentik database connection verified via health endpoint"
  else
    _assert_fail "Authentik health check returned HTTP ${code} (possible database issue)"
  fi
}

test_authentik_redis_connection() {
  # If Authentik worker is healthy, Redis connection is working
  local status
  status=$(docker_container_health "authentik-worker")

  if [[ "${status}" == "healthy" ]]; then
    _assert_pass "Authentik Redis connection verified via worker health"
  else
    _assert_fail "Authentik worker not healthy (possible Redis issue): ${status}"
  fi
}

# ---------------------------------------------------------------------------
# Level 1 — Network
# ---------------------------------------------------------------------------

test_authentik_on_proxy_network() {
  assert_container_on_network "authentik-server" "proxy"
}

test_authentik_on_internal_network() {
  assert_container_on_network "authentik-server" "internal"
}

# ---------------------------------------------------------------------------
# Level 1 — Configuration
# ---------------------------------------------------------------------------

test_sso_compose_valid() {
  local compose_file="${PROJECT_ROOT}/stacks/sso/docker-compose.yml"

  if [[ ! -f "${compose_file}" ]]; then
    _assert_skip "SSO compose file not found"
    return 0
  fi

  assert_compose_valid "${compose_file}"
}
