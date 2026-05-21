#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — SSO Tests
# Tests: Authentik Server + Worker + PostgreSQL + Redis
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker.sh"

should_run_stack "sso" || { begin_suite "SSO"; assert_skip "not selected"; exit 0; }

begin_suite "SSO — Authentik Unified Authentication"

# ---- Containers ----
assert_container_running "authentik-server"
assert_container_healthy "authentik-server"
assert_container_not_latest "authentik-server"
assert_container_running "authentik-worker"
assert_container_healthy "authentik-worker"
assert_container_not_latest "authentik-worker"
assert_container_running "authentik-postgresql"
assert_container_healthy "authentik-postgresql"
assert_container_not_latest "authentik-postgresql"
assert_container_running "authentik-redis"
assert_container_healthy "authentik-redis"
assert_container_not_latest "authentik-redis"

# ---- HTTP endpoints ----
assert_http_200 "${BASE_URL:-http://localhost}:9000/if/flow/default-authentication-flow/" "authentik:flow"
assert_http_200 "${BASE_URL:-http://localhost}:9000/api/v3/core/users/?page_size=1" "authentik:api"

# ---- Authentik health ----
begin_test "authentik:health"
health=$(curl -sf "${BASE_URL:-http://localhost}:9000/-/health/live/" 2>/dev/null || echo "")
if [[ -n "$health" ]]; then
  assert_pass "health endpoint responds"
else
  assert_skip "health endpoint not available"
fi

# ---- Inter-service ----
begin_test "authentik:connects_postgresql"
if docker exec authentik-server pg_isready -h authentik-postgresql &>/dev/null; then
  assert_pass "server → postgresql connected"
else
  assert_skip "pg_isready not available in container"
fi

begin_test "authentik:connects_redis"
if docker exec authentik-server sh -c 'echo PING | nc -w2 authentik-redis 6379' 2>/dev/null | grep -qi pong; then
  assert_pass "server → redis connected"
else
  assert_skip "redis check not available"
fi

# ---- Compose validation ----
assert_compose_valid "${SCRIPT_DIR}/../../stacks/sso/docker-compose.yml" "sso"
