#!/usr/bin/env bash
# =============================================================================
# SSO Stack Tests
# =============================================================================

test_authentik_server_running() {
  assert_container_running "authentik-server"
}

test_authentik_worker_running() {
  assert_container_running "authentik-worker"
}

test_authentik_postgres_running() {
  assert_container_running "authentik-postgres"
}

test_authentik_redis_running() {
  assert_container_running "authentik-redis"
}

test_authentik_server_healthy() {
  assert_container_healthy "authentik-server" 120
}

test_authentik_postgres_healthy() {
  assert_container_healthy "authentik-postgres" 60
}

test_authentik_redis_healthy() {
  assert_container_healthy "authentik-redis" 60
}

test_authentik_api_health() {
  assert_http_200 "http://localhost:9000/-/health/ready/" 10
}

test_authentik_login_page() {
  assert_http_response "http://localhost:9000/if/flow/default-authentication-flow/" "authentik" 10
}

test_authentik_admin_api() {
  assert_http_200 "http://localhost:9000/api/v3/admin/system/" 10
}

# Run all SSO tests
run_test_with_timing "sso" test_authentik_server_running "Authentik server running"
run_test_with_timing "sso" test_authentik_worker_running "Authentik worker running"
run_test_with_timing "sso" test_authentik_postgres_running "Authentik PostgreSQL running"
run_test_with_timing "sso" test_authentik_redis_running "Authentik Redis running"
run_test_with_timing "sso" test_authentik_server_healthy "Authentik server healthy"
run_test_with_timing "sso" test_authentik_postgres_healthy "Authentik PostgreSQL healthy"
run_test_with_timing "sso" test_authentik_redis_healthy "Authentik Redis healthy"
run_test_with_timing "sso" test_authentik_api_health "Authentik API health"
run_test_with_timing "sso" test_authentik_login_page "Authentik login page"
run_test_with_timing "sso" test_authentik_admin_api "Authentik admin API"
