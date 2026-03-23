#!/usr/bin/env bash
# =============================================================================
# HomeLab — SSO (Authentik) Tests
# =============================================================================
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib"; pwd)"
source "$_LIB_DIR/assert.sh"

test_sso_server_running() {
  assert_container_running "authentik-server" "Authentik server should be running"
}

test_sso_worker_running() {
  assert_container_running "authentik-worker" "Authentik worker should be running"
}

test_sso_postgresql_running() {
  assert_container_running "authentik-postgresql" "Authentik PostgreSQL should be running"
}

test_sso_redis_running() {
  assert_container_running "authentik-redis" "Authentik Redis should be running"
}

test_sso_http_response() {
  assert_http_200 "http://localhost:9000/if/flow/default-authentication-flow/" 30 "Authentik login flow should respond"
}

test_sso_no_latest_tags() {
  assert_no_latest_images "$BASE_DIR/stacks/sso" "SSO stack should pin image versions"
}
