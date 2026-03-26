#!/usr/bin/env bash
# backup-restore.test.sh - Backup & Restore E2E 测试
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"
STACK_NAME="e2e-backup"

test_database_containers() {
    test_start "Backup - PostgreSQL 容器正常"
    local pg_state; pg_state=$(docker inspect -f '{{.State.Running}}' homelab-postgres 2>/dev/null)
    if [[ "$pg_state" == "true" ]]; then test_end "Backup - PostgreSQL 容器正常" "PASS"
    else test_end "Backup - PostgreSQL 容器正常" "FAIL"; return 1; fi
    
    test_start "Backup - MariaDB 容器正常"
    local maria_state; maria_state=$(docker inspect -f '{{.State.Running}}' homelab-mariadb 2>/dev/null)
    if [[ "$maria_state" == "true" ]]; then test_end "Backup - MariaDB 容器正常" "PASS"
    else test_end "Backup - MariaDB 容器正常" "FAIL"; return 1; fi
}

test_volumes() {
    test_start "Backup - PostgreSQL 卷存在"
    local pg_volumes; pg_volumes=$(get_container_volumes "homelab-postgres")
    if [[ -n "$pg_volumes" ]]; then test_end "Backup - PostgreSQL 卷存在" "PASS"
    else test_end "Backup - PostgreSQL 卷存在" "FAIL"; return 1; fi
}

test_docker_backup_capability() {
    test_start "Backup - 可以列出 Docker 卷"
    local volumes; volumes=$(docker volume ls --format '{{.Name}}' 2>/dev/null)
    if [[ -n "$volumes" ]]; then test_end "Backup - 可以列出 Docker 卷" "PASS" "共 $(echo "$volumes" | wc -l) 个卷"
    else test_end "Backup - 可以列出 Docker 卷" "FAIL"; return 1; fi
}

test_database_health() {
    test_start "Backup - PostgreSQL 可连接"
    if docker exec homelab-postgres pg_isready -U postgres &>/dev/null; then test_end "Backup - PostgreSQL 可连接" "PASS"
    else test_end "Backup - PostgreSQL 可连接" "FAIL"; return 1; fi
    
    test_start "Backup - MariaDB 可连接"
    if docker exec homelab-mariadb mysqladmin ping -u root --silent 2>/dev/null; then test_end "Backup - MariaDB 可连接" "PASS"
    else test_end "Backup - MariaDB 可连接" "FAIL"; return 1; fi
}

test_main() {
    test_group_start "$STACK_NAME"
    test_database_containers || true; test_volumes || true; test_docker_backup_capability || true; test_database_health || true
    test_group_end "$STACK_NAME" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "${SCRIPT_DIR}/lib/assert.sh"; source "${SCRIPT_DIR}/lib/docker.sh"; source "${SCRIPT_DIR}/lib/report.sh"
    report_init; test_main; print_summary "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
