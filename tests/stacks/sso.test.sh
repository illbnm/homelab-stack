#!/usr/bin/env bash
# =============================================================================
# SSO Stack Tests — Authentik (Server + Worker + PostgreSQL + Redis)
# =============================================================================

log_group "SSO (Authentik)"

# --- Level 1: Container health ---

test_authentik_server_running() {
  assert_container_running "authentik-server"
  assert_container_healthy "authentik-server"
  assert_container_not_restarting "authentik-server"
}

test_authentik_worker_running() {
  assert_container_running "authentik-worker"
  assert_container_not_restarting "authentik-worker"
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

# --- Level 1: Network ---
test_sso_network() {
  assert_network_exists "sso"
  for c in authentik-server authentik-worker authentik-postgres authentik-redis; do
    if is_container_running "$c"; then
      assert_container_on_network "$c" "sso"
    fi
  done
  # Server must also be on proxy network
  if is_container_running "authentik-server"; then
    assert_container_on_network "authentik-server" "proxy"
  fi
}

test_sso_network

# --- Level 2: HTTP endpoints ---
if [[ "${TEST_LEVEL:-99}" -ge 2 ]]; then

  test_authentik_http() {
    require_container "authentik-server" || return
    # Authentik flow page
    assert_http_ok "http://localhost:9000/if/flow/default-authentication-flow/" \
      "Authentik auth flow page"
    # API endpoint
    assert_http_ok "http://localhost:9000/api/v3/core/users/?page_size=1" \
      "Authentik API /api/v3/core/users"
  }

  test_authentik_http
fi

# --- Level 3: Service interconnection ---
if [[ "${TEST_LEVEL:-99}" -ge 3 ]]; then

  test_authentik_db_connection() {
    require_container "authentik-postgres" || return
    local result
    result=$(docker_exec "authentik-postgres" pg_isready -U authentik -d authentik 2>/dev/null)
    assert_contains "$result" "accepting connections" "Authentik PostgreSQL accepting connections"
  }

  test_authentik_redis_connection() {
    require_container "authentik-redis" || return
    local result
    result=$(docker_exec "authentik-redis" redis-cli -a "${AUTHENTIK_REDIS_PASSWORD:-changeme}" ping 2>/dev/null)
    assert_eq "$result" "PONG" "Authentik Redis PING → PONG"
  }

  test_authentik_db_connection
  test_authentik_redis_connection
fi

# --- Image tags ---
for c in authentik-server authentik-worker authentik-postgres authentik-redis; do
  if is_container_running "$c"; then
    assert_container_image_not_latest "$c"
  fi
done
