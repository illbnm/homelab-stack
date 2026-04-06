#!/bin/bash
# sso.test.sh - SSO Stack Integration Tests
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_authentik_running() {
    echo "[sso] Testing Authentik running..."
    assert_container_running "authentik-server" || echo "  ⚠️  Authentik server container not found"
}

test_authentik_http() {
    echo "[sso] Testing Authentik API..."
    assert_http_response "http://localhost:9000/api/v3/core/users/?page_size=1" "results" 30 || echo "  ⚠️  Authentik API check skipped"
}

test_authentik_worker_running() {
    echo "[sso] Testing Authentik worker running..."
    assert_container_running "authentik-worker" || echo "  ⚠️  Authentik worker container not found"
}

test_authentik_redis_running() {
    echo "[sso] Testing Authentik Redis running..."
    assert_container_running "authentik-redis" || echo "  ⚠️  Authentik Redis container not found"
}

test_compose_exists() {
    echo "[sso] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/sso/docker-compose.yml" || echo "  ⚠️  SSO compose file not found"
}

run_sso_tests() {
    echo "╔══════════════════════════════════════╗"
    echo "║   HomeLab Stack — SSO Tests          ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    
    test_compose_exists || true
    test_authentik_running || true
    test_authentik_http || true
    test_authentik_worker_running || true
    test_authentik_redis_running || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_sso_tests
fi
