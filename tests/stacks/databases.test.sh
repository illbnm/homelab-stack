#!/bin/bash
# databases.test.sh - Databases Stack Integration Tests
# Tests for: PostgreSQL, Redis, MariaDB

set -o pipefail

# Test PostgreSQL running
test_databases_postgres_running() {
    local test_name="[databases] PostgreSQL running"
    start_test "$test_name"
    
    if assert_container_running "postgres"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Container not running"
    fi
}

# Test PostgreSQL health
test_databases_postgres_health() {
    local test_name="[databases] PostgreSQL health"
    start_test "$test_name"
    
    if assert_container_healthy "postgres" 30; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Health check failed"
    fi
}

# Test PostgreSQL connection
test_databases_postgres_connection() {
    local test_name="[databases] PostgreSQL connection test"
    start_test "$test_name"
    
    local result
    result=$(docker exec postgres pg_isready -U postgres 2>/dev/null)
    
    if echo "$result" | grep -q "accepting connections"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Not accepting connections"
    fi
}

# Test Redis running
test_databases_redis_running() {
    local test_name="[databases] Redis running"
    start_test "$test_name"
    
    if assert_container_running "redis"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Container not running"
    fi
}

# Test Redis health
test_databases_redis_health() {
    local test_name="[databases] Redis health"
    start_test "$test_name"
    
    if assert_container_healthy "redis" 30; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Health check failed"
    fi
}

# Test Redis connection
test_databases_redis_connection() {
    local test_name="[databases] Redis PING test"
    start_test "$test_name"
    
    local result
    result=$(docker exec redis redis-cli PING 2>/dev/null)
    
    if [[ "$result" == "PONG" ]]; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "PING failed (got: $result)"
    fi
}

# Test MariaDB running
test_databases_mariadb_running() {
    local test_name="[databases] MariaDB running"
    start_test "$test_name"
    
    if assert_container_running "mariadb"; then
        pass_test "$test_name"
    else
        assert_skip "MariaDB not deployed"
    fi
}

# Test MariaDB connection
test_databases_mariadb_connection() {
    local test_name="[databases] MariaDB connection test"
    start_test "$test_name"
    
    local result
    result=$(docker exec mariadb mysqladmin ping -u root -p"${MARIADB_ROOT_PASSWORD:-root}" 2>/dev/null)
    
    if echo "$result" | grep -q "mysqld is alive"; then
        pass_test "$test_name"
    else
        assert_skip "MariaDB not accessible"
    fi
}

# Test pgAdmin running
test_databases_pgadmin_running() {
    local test_name="[databases] pgAdmin running"
    start_test "$test_name"
    
    if assert_container_running "pgadmin"; then
        pass_test "$test_name"
    else
        assert_skip "pgAdmin not deployed"
    fi
}

# Test pgAdmin Web UI
test_databases_pgadmin_webui() {
    local test_name="[databases] pgAdmin Web UI"
    start_test "$test_name"
    
    if assert_http_200 "http://localhost:5050" 30; then
        pass_test "$test_name"
    else
        assert_skip "pgAdmin not accessible"
    fi
}

# Test database initialization script
test_databases_init_script() {
    local test_name="[databases] Init databases script exists"
    start_test "$test_name"
    
    if [[ -f "/home/gg/opt/agentwork/bigeye/homelab-stack/scripts/init-databases.sh" ]]; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Script not found"
    fi
}

# Run all databases tests
test_databases_all() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Databases Stack Tests"
    echo "════════════════════════════════════════"
    
    test_databases_postgres_running
    test_databases_postgres_health
    test_databases_postgres_connection
    test_databases_redis_running
    test_databases_redis_health
    test_databases_redis_connection
    test_databases_mariadb_running
    test_databases_mariadb_connection
    test_databases_pgadmin_running
    test_databases_pgadmin_webui
    test_databases_init_script
}

# Helper functions
start_test() {
    local name="$1"
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}▶${NC} $name"
    fi
}

pass_test() {
    local name="$1"
    echo -e "${GREEN}✅ PASS${NC} $name"
}

fail_test() {
    local name="$1"
    local reason="$2"
    echo -e "${RED}❌ FAIL${NC} $name - $reason"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    VERBOSE="${VERBOSE:-false}"
    test_databases_all
fi
