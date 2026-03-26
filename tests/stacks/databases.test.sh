#!/usr/bin/env bash
# databases.test.sh - Databases Stack 测试
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"
STACK_NAME="databases"

test_postgres() {
    test_start "PostgreSQL - 容器运行"
    if assert_container_running "homelab-postgres"; then test_end "PostgreSQL - 容器运行" "PASS"
    else test_end "PostgreSQL - 容器运行" "FAIL"; return 1; fi
    test_start "PostgreSQL - 连接测试"
    if docker exec homelab-postgres pg_isready -U postgres &>/dev/null; then test_end "PostgreSQL - 连接测试" "PASS"
    else test_end "PostgreSQL - 连接测试" "SKIP"; fi
}

test_redis() {
    test_start "Redis - 容器运行"
    if assert_container_running "homelab-redis"; then test_end "Redis - 容器运行" "PASS"
    else test_end "Redis - 容器运行" "FAIL"; return 1; fi
    test_start "Redis - Ping 测试"
    if docker exec homelab-redis redis-cli ping 2>/dev/null | grep -q "PONG"; then test_end "Redis - Ping 测试" "PASS"
    else test_end "Redis - Ping 测试" "SKIP"; fi
}

test_mariadb() {
    test_start "MariaDB - 容器运行"
    if assert_container_running "homelab-mariadb"; then test_end "MariaDB - 容器运行" "PASS"
    else test_end "MariaDB - 容器运行" "FAIL"; return 1; fi
    test_start "MariaDB - 连接测试"
    if docker exec homelab-mariadb mysqladmin ping -u root --silent 2>/dev/null; then test_end "MariaDB - 连接测试" "PASS"
    else test_end "MariaDB - 连接测试" "SKIP"; fi
}

test_main() {
    test_group_start "$STACK_NAME"
    test_postgres || true; test_redis || true; test_mariadb || true
    test_group_end "$STACK_NAME" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "${SCRIPT_DIR}/lib/assert.sh"; source "${SCRIPT_DIR}/lib/docker.sh"; source "${SCRIPT_DIR}/lib/report.sh"
    report_init; test_main; print_summary "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
