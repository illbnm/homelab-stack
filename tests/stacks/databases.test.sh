#!/usr/bin/env bash
# =============================================================================
# Databases Stack Tests (PostgreSQL, Redis, MariaDB)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.."; pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/report.sh"

STACK_NAME="databases"
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env" 2>/dev/null || true

test_postgres_running() {
    local start=$(date +%s)
    assert_container_running "homelab-postgres" "PostgreSQL running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "postgres_running" "$?" "$duration" "$STACK_NAME"
}

test_postgres_healthy() {
    local start=$(date +%s)
    assert_container_healthy "homelab-postgres" 60
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "postgres_healthy" "$?" "$duration" "$STACK_NAME"
}

test_redis_running() {
    local start=$(date +%s)
    assert_container_running "homelab-redis" "Redis running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "redis_running" "$?" "$duration" "$STACK_NAME"
}

test_mariadb_running() {
    local start=$(date +%s)
    assert_container_running "homelab-mariadb" "MariaDB running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "mariadb_running" "$?" "$duration" "$STACK_NAME"
}

test_postgres_port() {
    local start=$(date +%s)
    assert_port_open "localhost" 5432 10
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "postgres_port" "$?" "$duration" "$STACK_NAME"
}

test_redis_port() {
    local start=$(date +%s)
    assert_port_open "localhost" 6379 10
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "redis_port" "$?" "$duration" "$STACK_NAME"
}

test_mariadb_port() {
    local start=$(date +%s)
    assert_port_open "localhost" 3306 10
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "mariadb_port" "$?" "$duration" "$STACK_NAME"
}

run_databases_tests() {
    report_init
    report_stack "Databases Stack"

    test_postgres_running
    test_postgres_healthy
    test_redis_running
    test_mariadb_running
    test_postgres_port
    test_redis_port
    test_mariadb_port

    local duration=$(echo "$(date +%s) - $REPORT_START_TIME" | bc)
    report_summary $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
    report_export_json $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_databases_tests
fi
