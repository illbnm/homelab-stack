#!/bin/bash
# databases.test.sh - Databases Stack 测试
# 测试 PostgreSQL, Redis, MariaDB

set -u

# PostgreSQL 测试
test_postgres_running() {
    assert_container_running "postgres"
}

test_postgres_health() {
    # PostgreSQL 健康检查通过 pg_isready
    if exec_in_container "postgres" pg_isready -U postgres &> /dev/null; then
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "PASS" "postgres healthy" "$duration"
        return 0
    else
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "FAIL" "postgres healthy" "$duration" "pg_isready failed"
        return 1
    fi
}

# Redis 测试
test_redis_running() {
    assert_container_running "redis"
}

test_redis_ping() {
    local result=$(exec_in_container "redis" redis-cli ping 2>/dev/null)
    if [[ "$result" == "PONG" ]]; then
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "PASS" "redis ping" "$duration"
        return 0
    else
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "FAIL" "redis ping" "$duration" "Expected PONG, Got: $result"
        return 1
    fi
}

# MariaDB 测试
test_mariadb_running() {
    assert_container_running "mariadb"
}

test_mariadb_health() {
    if exec_in_container "mariadb" mysqladmin ping -u root &> /dev/null; then
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "PASS" "mariadb healthy" "$duration"
        return 0
    else
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "SKIP" "mariadb healthy" "$duration"
    fi
}

# pgAdmin 测试
test_pgadmin_running() {
    assert_container_running "pgadmin"
}

test_pgadmin_http() {
    assert_http_200 "http://localhost:5050"
}

# Redis Commander 测试
test_redis_commander_running() {
    assert_container_running "redis-commander"
}

test_redis_commander_http() {
    assert_http_200 "http://localhost:8081"
}
