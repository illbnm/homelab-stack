#!/usr/bin/env bash
# =============================================================================
# sso.test.sh — SSO (Authentik) tests
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1: Container health
# ---------------------------------------------------------------------------
test_suite "SSO (Authentik) — Containers"

test_authentik_server_running() {
  assert_container_running "authentik-server"
  assert_container_healthy "authentik-server"
}

test_authentik_worker_running() {
  assert_container_running "authentik-worker"
}

test_authentik_postgres_running() {
  assert_container_running "authentik-postgres"
  assert_container_healthy "authentik-postgres"
}

test_authentik_redis_running() {
  assert_container_running "authentik-redis"
  assert_container_healthy "authentik-redis"
}

test_authentik_server_running
test_authentik_worker_running
test_authentik_postgres_running
test_authentik_redis_running

# ---------------------------------------------------------------------------
# Level 2: HTTP endpoints
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 2 ]]; then
  test_suite "SSO (Authentik) — HTTP Endpoints"

  test_authentik_api() {
    # Authentik API requires auth, but the flow page is public
    assert_http_status "http://localhost:9000/if/flow/default-authentication-flow/" "200" \
      "Authentik login flow page"
  }

  test_authentik_health() {
    assert_http_200 "http://localhost:9000/-/health/live/" "Authentik health endpoint"
  }

  test_authentik_api
  test_authentik_health
fi

# ---------------------------------------------------------------------------
# Level 3: Service interconnection
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 3 ]]; then
  test_suite "SSO (Authentik) — Interconnection"

  test_authentik_db_connection() {
    local result
    result=$(docker_run_in "authentik-postgres" \
      psql -U "${AUTHENTIK_POSTGRES_USER:-authentik}" -d authentik -tAc "SELECT 1;" 2>/dev/null || echo "")
    assert_eq "$result" "1" "Authentik PostgreSQL connection"
  }

  test_authentik_redis_connection() {
    local result
    result=$(docker_run_in "authentik-redis" redis-cli ping 2>/dev/null || echo "")
    assert_eq "$result" "PONG" "Authentik Redis connection"
  }

  test_authentik_db_connection
  test_authentik_redis_connection
fi
