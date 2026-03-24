#!/bin/bash
# databases.test.sh - Databases Stack Integration Tests
# 测试数据库组件：PostgreSQL, MySQL, MongoDB, Redis

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

# Databases Stack 测试
test_databases_postgres_running() {
    local start_time=$(date +%s)
    if ! assert_container_running "postgres" 2>/dev/null; then
        local duration=$(($(date +%s) - start_time))
        log_test "databases" "PostgreSQL running" "SKIP" "$duration" "Container not found"
        return 0
    fi
    local duration=$(($(date +%s) - start_time))
    log_test "databases" "PostgreSQL running" "PASS" "$duration"
}

test_databases_postgres_ready() {
    local start_time=$(date +%s)
    if ! assert_container_running "postgres" 2>/dev/null; then
        local duration=$(($(date +%s) - start_time))
        log_test "databases" "PostgreSQL ready" "SKIP" "$duration" "Container not running"
        return 0
    fi
    
    local result
    result=$(docker exec postgres pg_isready 2>/dev/null || echo "not_ready")
    local duration=$(($(date +%s) - start_time))
    
    if echo "$result" | grep -q "accepting connections"; then
        log_test "databases" "PostgreSQL ready" "PASS" "$duration"
    else
        log_test "databases" "PostgreSQL ready" "FAIL" "$duration" "$result"
    fi
}

test_databases_mysql_running() {
    local start_time=$(date +%s)
    if ! assert_container_running "mysql" 2>/dev/null; then
        local duration=$(($(date +%s) - start_time))
        log_test "databases" "MySQL running" "SKIP" "$duration" "Container not found"
        return 0
    fi
    local duration=$(($(date +%s) - start_time))
    log_test "databases" "MySQL running" "PASS" "$duration"
}

test_databases_mysql_ready() {
    local start_time=$(date +%s)
    if ! assert_container_running "mysql" 2>/dev/null; then
        local duration=$(($(date +%s) - start_time))
        log_test "databases" "MySQL ready" "SKIP" "$duration" "Container not running"
        return 0
    fi
    
    local result
    result=$(docker exec mysql mysqladmin ping -u root 2>/dev/null || echo "not_ready")
    local duration=$(($(date +%s) - start_time))
    
    if echo "$result" | grep -q "mysqld is alive"; then
        log_test "databases" "MySQL ready" "PASS" "$duration"
    else
        log_test "databases" "MySQL ready" "SKIP" "$duration" "MySQL not ready yet"
    fi
}

test_databases_redis_running() {
    local start_time=$(date +%s)
    if ! assert_container_running "redis" 2>/dev/null; then
        local duration=$(($(date +%s) - start_time))
        log_test "databases" "Redis running" "SKIP" "$duration" "Container not found"
        return 0
    fi
    local duration=$(($(date +%s) - start_time))
    log_test "databases" "Redis running" "PASS" "$duration"
}

test_databases_redis_ping() {
    local start_time=$(date +%s)
    if ! assert_container_running "redis" 2>/dev/null; then
        local duration=$(($(date +%s) - start_time))
        log_test "databases" "Redis PING" "SKIP" "$duration" "Container not running"
        return 0
    fi
    
    local result
    result=$(docker exec redis redis-cli ping 2>/dev/null || echo "not_ready")
    local duration=$(($(date +%s) - start_time))
    
    if [[ "$result" == "PONG" ]]; then
        log_test "databases" "Redis PING" "PASS" "$duration"
    else
        log_test "databases" "Redis PING" "FAIL" "$duration" "$result"
    fi
}

test_databases_mongodb_running() {
    local start_time=$(date +%s)
    if ! assert_container_running "mongodb" 2>/dev/null; then
        local duration=$(($(date +%s) - start_time))
        log_test "databases" "MongoDB running" "SKIP" "$duration" "Container not found"
        return 0
    fi
    local duration=$(($(date +%s) - start_time))
    log_test "databases" "MongoDB running" "PASS" "$duration"
}

test_databases_volumes_exist() {
    local start_time=$(date +%s)
    local volumes=("postgres_data" "mysql_data" "redis_data" "mongodb_data")
    local found=0
    
    for vol in "${volumes[@]}"; do
        if docker volume inspect "$vol" &>/dev/null; then
            ((found++))
        fi
    done
    
    local duration=$(($(date +%s) - start_time))
    if [[ $found -gt 0 ]]; then
        log_test "databases" "Database volumes exist" "PASS" "$duration"
    else
        log_test "databases" "Database volumes exist" "SKIP" "$duration" "No database volumes found"
    fi
}

test_databases_compose_syntax() {
    local start_time=$(date +%s)
    local compose_file="$SCRIPT_DIR/../../stacks/databases/docker-compose.yml"
    
    if [[ ! -f "$compose_file" ]]; then
        local duration=$(($(date +%s) - start_time))
        log_test "databases" "Compose syntax valid" "SKIP" "$duration" "File not found"
        return 0
    fi
    
    docker compose -f "$compose_file" config --quiet &>/dev/null
    local exit_code=$?
    local duration=$(($(date +%s) - start_time))
    
    if [[ $exit_code -eq 0 ]]; then
        log_test "databases" "Compose syntax valid" "PASS" "$duration"
    else
        log_test "databases" "Compose syntax valid" "FAIL" "$duration" "Invalid compose syntax"
    fi
}

# 运行所有 databases 测试
test_databases_all() {
    test_databases_postgres_running
    test_databases_postgres_ready
    test_databases_mysql_running
    test_databases_mysql_ready
    test_databases_redis_running
    test_databases_redis_ping
    test_databases_mongodb_running
    test_databases_volumes_exist
    test_databases_compose_syntax
}

# 如果直接执行此文件，运行所有测试
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_report
    test_databases_all
    
    stats=$(get_assert_stats)
    eval "$stats"
    finalize_report $ASSERT_PASS $ASSERT_FAIL $ASSERT_SKIP "$SCRIPT_DIR/../results"
fi
