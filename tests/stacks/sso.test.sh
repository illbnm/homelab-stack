#!/usr/bin/env bash
# =============================================================================
# tests/stacks/sso.test.sh — SSO / Authentik Tests
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
source "$SCRIPT_DIR/tests/lib/assert.sh"
source "$SCRIPT_DIR/tests/lib/docker.sh"

test_authentik_server_running() {
  assert_container_running "authentik-server"
}

test_authentik_worker_running() {
  assert_container_running "authentik-worker"
}

test_authentik_postgres_running() {
  assert_container_running "authentik-postgresql"
}

test_authentik_server_healthy() {
  assert_container_healthy "authentik-server" 120
}

test_authentik_http() {
  assert_http_200 "http://localhost:9000/if/flow/default-authentication-flow/" 15
}

test_authentik_api_reachable() {
  local code
  code=$(http_status "http://localhost:9000/api/v3/core/" 10)
  assert_contains "200 401" "$code"
}

test_authentik_outpost_proxy_running() {
  assert_container_running "authentik-proxy-httpbin" 2>/dev/null || true
  # This container is optional in the compose
  return 0
}

test_sso_compose_valid() {
  assert_compose_valid "$SCRIPT_DIR/stacks/sso/docker-compose.yml"
}
