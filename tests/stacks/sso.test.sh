#!/bin/bash
# sso.test.sh - SSO Stack 集成测试
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_authentik_running() {
    echo "[sso] Testing Authentik running..."
    assert_container_running "authentik-server"
}

test_authentik_http() {
    echo "[sso] Testing Authentik API..."
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "http://localhost:9000/api/v3/core/users/?page_size=1" 2>/dev/null)
    if [[ "$http_code" == "200" || "$http_code" == "401" || "$http_code" == "403" ]]; then
        echo -e "${GREEN}✅ PASS${NC} (Auth required)"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} Authentik API returned $http_code"
        return 1
    fi
}

test_authentik_worker_running() {
    echo "[sso] Testing Authentik Worker running..."
    assert_container_running "authentik-worker" || return 0
}

test_redis_running() {
    echo "[sso] Testing Redis running..."
    assert_container_running "redis" || return 0  # Used by Authentik
}

test_postgres_authentik_running() {
    echo "[sso] Testing PostgreSQL for Authentik running..."
    assert_container_running "authentik-db" || return 0
}

test_compose_exists() {
    echo "[sso] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/sso/docker-compose.yml"
}

run_sso_tests() {
    print_header "HomeLab Stack — SSO Tests"
    
    test_compose_exists || true
    test_authentik_running || true
    test_authentik_http || true
    test_authentik_worker_running || true
    test_redis_running || true
    test_postgres_authentik_running || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_sso_tests
fi
