#!/usr/bin/env bash
# =============================================================================
# SSO Stack Integration Tests
# Tests: Authentik, PostgreSQL, Redis
# =============================================================================

STACK_NAME="sso"

# =============================================================================
# Container Health Tests
# =============================================================================

test_authentik_server_running() {
  assert_container_running "authentik-server" "Authentik server should be running"
  assert_container_healthy "authentik-server" "Authentik server should be healthy within 90s"
}

test_authentik_worker_running() {
  assert_container_running "authentik-worker" "Authentik worker should be running"
}

test_postgresql_running() {
  assert_container_running "authentik-postgres" "PostgreSQL should be running"
  assert_container_healthy "authentik-postgres" "PostgreSQL should be healthy within 60s"
}

test_redis_running() {
  assert_container_running "authentik-redis" "Redis should be running"
  assert_container_healthy "authentik-redis" "Redis should be healthy within 30s"
}

# =============================================================================
# HTTP Endpoint Tests
# =============================================================================

test_authentik_api() {
  assert_http_200 "http://localhost:9000/-/health/ready/" "Authentik API should be accessible"
}

test_authentik_admin() {
  assert_http_200 "http://localhost:9000/if/admin/" "Authentik admin UI should be accessible"
}

# =============================================================================
# OIDC Discovery Tests
# =============================================================================

test_oidc_discovery() {
  assert_http_200 "http://localhost:9000/.well-known/openid-configuration" "OIDC discovery document should be accessible"
}

test_oauth_authorization_endpoint() {
  assert_http_200 "http://localhost:9000/application/o/authorize/" "OAuth authorization endpoint should be accessible"
}

test_oauth_token_endpoint() {
  assert_http_200 "http://localhost:9000/application/o/token/" "OAuth token endpoint should be accessible"
}

# =============================================================================
# Run Tests
# =============================================================================

run_all_tests() {
  echo "Running Container Health Tests..."
  test_authentik_server_running
  test_authentik_worker_running
  test_postgresql_running
  test_redis_running
  
  echo ""
  echo "Running HTTP Endpoint Tests..."
  test_authentik_api
  test_authentik_admin
  
  echo ""
  echo "Running OIDC Discovery Tests..."
  test_oidc_discovery
  test_oauth_authorization_endpoint
  test_oauth_token_endpoint
}
