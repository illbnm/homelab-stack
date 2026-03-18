#!/usr/bin/env bash
# =============================================================================
# sso.test.sh — SSO stack tests
# Services: Authentik (server + worker), PostgreSQL, Redis
# =============================================================================

# --- Authentik Server ---

test_authentik_server_running() {
  assert_container_running "authentik-server"
}

test_authentik_server_healthy() {
  assert_container_healthy "authentik-server"
}

test_authentik_health_endpoint() {
  assert_http_200 "http://localhost:9000/-/health/live/" 15
}

test_authentik_ready() {
  assert_http_200 "http://localhost:9000/-/health/ready/" 15
}

test_authentik_api() {
  assert_http_status "http://localhost:9000/api/v3/core/users/?page_size=1" 200 15
}

test_authentik_no_crash_loop() {
  assert_no_crash_loop "authentik-server" 3
}

test_authentik_in_proxy_network() {
  assert_container_in_network "authentik-server" "proxy"
}

# --- Authentik Worker ---

test_authentik_worker_running() {
  assert_container_running "authentik-worker"
}

test_authentik_worker_no_crash_loop() {
  assert_no_crash_loop "authentik-worker" 3
}

test_authentik_worker_no_errors() {
  assert_log_no_errors "authentik-worker" "FATAL\|panic\|CRITICAL" "1h"
}

# --- SSO Dependencies ---

test_sso_postgres_running() {
  assert_container_running "postgresql"
}

test_sso_postgres_healthy() {
  assert_container_healthy "postgresql"
}

test_sso_postgres_accepting_connections() {
  local msg="SSO PostgreSQL accepting connections"
  if docker exec postgresql pg_isready -U "${POSTGRES_USER:-authentik}" &>/dev/null; then
    _assert_pass "$msg"
  else
    _assert_fail "$msg" "pg_isready failed"
  fi
}

test_sso_redis_running() {
  assert_container_running "redis"
}

test_sso_redis_healthy() {
  assert_container_healthy "redis"
}

test_sso_redis_ping() {
  local msg="SSO Redis responds to PING"
  local result
  result=$(docker exec redis redis-cli ping 2>/dev/null) || {
    _assert_fail "$msg" "redis-cli failed"
    return 1
  }
  assert_eq "$result" "PONG" "$msg"
}

# --- OIDC Flow (Level 3 — inter-service) ---

test_authentik_oidc_discovery() {
  local msg="Authentik OIDC discovery endpoint"
  assert_http_200 "http://localhost:9000/application/o/.well-known/openid-configuration" 15
}

test_authentik_oidc_jwks() {
  local msg="Authentik OIDC JWKS endpoint"
  assert_http_body_contains \
    "http://localhost:9000/application/o/.well-known/openid-configuration" \
    "jwks_uri" 15
}
