#!/bin/bash
# =============================================================================
# SSO Stack Tests — HomeLab Stack
# =============================================================================
# Tests: Authentik, PostgreSQL, Redis
# Level: 1 + 2 + 5
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/docker.sh"

load_env() {
    [[ -f "$ROOT_DIR/.env" ]] && set -a && source "$ROOT_DIR/.env" && set +a
}
load_env

suite_start "SSO Stack"

test_authentik_server_running()   { assert_container_running "authentik-server"; }
test_authentik_worker_running()  { assert_container_running "authentik-worker" || true; }
test_authentik_postgres_running(){ assert_container_running "authentik-postgres"; }
test_authentik_redis_running()   { assert_container_running "authentik-redis"; }

test_authentik_http() {
    local domain="${DOMAIN:-localhost}"
    if [[ "$domain" == "localhost" ]]; then
        assert_http_200 "http://authentik-server:9000/outpost.goauthentik.io/auth/traefik" 25 || true
    else
        assert_http_200 "http://authentik.${domain}/api/v3/core/users/?page_size=1" 25
    fi
}

test_compose_syntax() {
    local failed=0
    for f in $(find "$ROOT_DIR/stacks/sso" -name 'docker-compose*.yml'); do
        docker compose -f "$f" config --quiet 2>/dev/null || { echo "Invalid: $f"; failed=1; }
    done
    [[ $failed -eq 0 ]]
}
test_no_latest_tags()             { assert_no_latest_images "stacks/sso"; }

tests=(test_authentik_server_running test_authentik_worker_running
       test_authentik_postgres_running test_authentik_redis_running
       test_authentik_http
       test_compose_syntax test_no_latest_tags)

for t in "${tests[@]}"; do $t; done
summary
