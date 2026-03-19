#!/bin/bash
# databases.test.sh - Databases Stack 集成测试
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_postgres_running() {
    echo "[databases] Testing PostgreSQL running..."
    assert_container_running "postgres"
}

test_postgres_health() {
    echo "[databases] Testing PostgreSQL health..."
    local result=$(docker exec postgres pg_isready -U postgres 2>&1)
    if echo "$result" | grep -q "accepting connections"; then
        echo -e "${GREEN}✅ PASS${NC} PostgreSQL accepting connections"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} PostgreSQL not ready"
        return 1
    fi
}

test_mysql_running() {
    echo "[databases] Testing MySQL running..."
    assert_container_running "mysql" || return 0  # Optional
}

test_mysql_health() {
    echo "[databases] Testing MySQL health..."
    local result=$(docker exec mysql mysqladmin ping -u root 2>&1)
    if echo "$result" | grep -q "mysqld is alive"; then
        echo -e "${GREEN}✅ PASS${NC} MySQL accepting connections"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} MySQL not ready"
        return 1
    fi
}

test_mongodb_running() {
    echo "[databases] Testing MongoDB running..."
    assert_container_running "mongodb" || return 0  # Optional
}

test_redis_running() {
    echo "[databases] Testing Redis running..."
    assert_container_running "redis"
}

test_redis_ping() {
    echo "[databases] Testing Redis ping..."
    local result=$(docker exec redis redis-cli ping 2>&1)
    if [[ "$result" == "PONG" ]]; then
        echo -e "${GREEN}✅ PASS${NC} Redis responding"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} Redis not responding"
        return 1
    fi
}

test_influxdb_running() {
    echo "[databases] Testing InfluxDB running..."
    assert_container_running "influxdb" || return 0  # Optional
}

test_influxdb_http() {
    echo "[databases] Testing InfluxDB HTTP..."
    assert_http_200 "http://localhost:8086/health" 30 || return 0
}

test_compose_exists() {
    echo "[databases] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/databases/docker-compose.yml"
}

run_databases_tests() {
    print_header "HomeLab Stack — Databases Tests"
    
    test_compose_exists || true
    test_postgres_running || true
    test_postgres_health || true
    test_mysql_running || true
    test_mysql_health || true
    test_mongodb_running || true
    test_redis_running || true
    test_redis_ping || true
    test_influxdb_running || true
    test_influxdb_http || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_databases_tests
fi
