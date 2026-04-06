#!/bin/bash
# databases.test.sh - Databases Stack Integration Tests
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_postgres_running() {
    echo "[databases] Testing PostgreSQL running..."
    assert_container_running "postgres" || echo "  ⚠️  PostgreSQL container not found"
}

test_mysql_running() {
    echo "[databases] Testing MySQL running..."
    assert_container_running "mysql" || echo "  ⚠️  MySQL container not found"
}

test_redis_running() {
    echo "[databases] Testing Redis running..."
    assert_container_running "redis" || echo "  ⚠️  Redis container not found"
}

test_mongodb_running() {
    echo "[databases] Testing MongoDB running..."
    assert_container_running "mongodb" || echo "  ⚠️  MongoDB container not found"
}

test_compose_exists() {
    echo "[databases] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/databases/docker-compose.yml" || echo "  ⚠️  Databases compose file not found"
}

run_databases_tests() {
    echo "╔══════════════════════════════════════╗"
    echo "║   HomeLab Stack — Databases Tests    ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    
    test_compose_exists || true
    test_postgres_running || true
    test_mysql_running || true
    test_redis_running || true
    test_mongodb_running || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_databases_tests
fi
