#!/usr/bin/env bash
# =============================================================================
# SSO (Authentik) Stack Tests
# =============================================================================

# Container health
assert_container_running authentik-server
assert_container_healthy authentik-server 90
assert_container_running authentik-worker
assert_container_running authentik-postgresql
assert_container_healthy authentik-postgresql 30
assert_container_running authentik-redis
assert_container_healthy authentik-redis 30

# HTTP endpoints
assert_http_200 "http://localhost:9000/-/health/ready/" 30

# Authentik readiness
test_start "Authentik readiness probe"
ready=$(curl -sf -o /dev/null -w '%{http_code}' "http://localhost:9000/-/health/ready/" 2>/dev/null || echo "000")
if [[ "$ready" =~ ^2 ]]; then
  test_pass
else
  test_fail "Authentik readiness returned HTTP $ready"
fi

# Authentik liveness
test_start "Authentik liveness probe"
alive=$(curl -sf -o /dev/null -w '%{http_code}' "http://localhost:9000/-/health/live/" 2>/dev/null || echo "000")
if [[ "$alive" =~ ^2 ]]; then
  test_pass
else
  test_fail "Authentik liveness returned HTTP $alive"
fi

# Authentik login flow accessible
test_start "Authentik auth flow page"
flow=$(curl -sf -o /dev/null -w '%{http_code}' "http://localhost:9000/if/flow/default-authentication-flow/" 2>/dev/null || echo "000")
if [[ "$flow" =~ ^[23] ]]; then
  test_pass
else
  test_fail "Authentik auth flow page returned HTTP $flow"
fi

# SSO network isolation
test_start "SSO internal network exists"
if docker network inspect sso >/dev/null 2>&1; then
  test_pass
else
  test_fail "Docker 'sso' network not found"
fi

# Verify postgres is accessible from sso network
test_start "PostgreSQL reachable from sso network"
if docker exec authentik-postgresql pg_isready -U authentik -d authentik >/dev/null 2>&1; then
  test_pass
else
  test_fail "PostgreSQL not responding to pg_isready"
fi
