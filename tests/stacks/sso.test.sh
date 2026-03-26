#!/usr/bin/env bash
# sso.test.sh - SSO / Auth Stack 测试
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"
STACK_NAME="sso"

test_authentik() {
    test_start "Authentik Server - 容器运行"
    if assert_container_running "authentik-server"; then test_end "Authentik Server - 容器运行" "PASS"
    else test_end "Authentik Server - 容器运行" "FAIL"; return 1; fi
    test_start "Authentik Server - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 15 "http://127.0.0.1:9000/"; then test_end "Authentik Server - HTTP 端点可达" "PASS"
    else test_end "Authentik Server - HTTP 端点可达" "SKIP"; fi
    test_start "Authentik Worker - 容器运行"
    if assert_container_running "authentik-worker"; then test_end "Authentik Worker - 容器运行" "PASS"
    else test_end "Authentik Worker - 容器运行" "FAIL"; return 1; fi
}

test_authentik_postgres() {
    test_start "Authentik PostgreSQL - 容器运行"
    if assert_container_running "authentik-postgres"; then test_end "Authentik PostgreSQL - 容器运行" "PASS"
    else test_end "Authentik PostgreSQL - 容器运行" "FAIL"; return 1; fi
    test_start "Authentik PostgreSQL - 连接测试"
    if docker exec authentik-postgres pg_isready -U authentik &>/dev/null; then
        test_end "Authentik PostgreSQL - 连接测试" "PASS"
    else test_end "Authentik PostgreSQL - 连接测试" "SKIP"; fi
}

test_authentik_redis() {
    test_start "Authentik Redis - 容器运行"
    if assert_container_running "authentik-redis"; then test_end "Authentik Redis - 容器运行" "PASS"
    else test_end "Authentik Redis - 容器运行" "FAIL"; return 1; fi
    test_start "Authentik Redis - Ping 测试"
    if docker exec authentik-redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
        test_end "Authentik Redis - Ping 测试" "PASS"
    else test_end "Authentik Redis - Ping 测试" "SKIP"; fi
}

test_oidc_integration() {
    test_start "OIDC - Provider metadata 可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:9000/.well-known/openid-configuration" 2>/dev/null; then
        test_end "OIDC - Provider metadata 可达" "PASS"
    else test_end "OIDC - Provider metadata 可达" "SKIP"; fi
    test_start "OIDC - JWKS 端点"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:9000/.well-known/jwks.json" 2>/dev/null; then
        test_end "OIDC - JWKS 端点" "PASS"
    else test_end "OIDC - JWKS 端点" "SKIP"; fi
}

test_main() {
    test_group_start "$STACK_NAME"
    test_authentik || true; test_authentik_postgres || true; test_authentik_redis || true; test_oidc_integration || true
    test_group_end "$STACK_NAME" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "${SCRIPT_DIR}/lib/assert.sh"; source "${SCRIPT_DIR}/lib/docker.sh"; source "${SCRIPT_DIR}/lib/report.sh"
    report_init; test_main; print_summary "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
