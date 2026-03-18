#!/usr/bin/env bash
# databases.test.sh - Tests for database stack (postgresql, redis, mariadb)
# Copyright (c) 2026 homelab-stack contributors
# SPDX-License-Identifier: MIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"
source "${SCRIPT_DIR}/../lib/report.sh"

STACK_NAME="databases"
SERVICES=(postgresql redis mariadb)

setup() {
    assert_reset
    report_init "$STACK_NAME"
}

teardown() {
    report_write_json
    report_print_summary
}

test_compose_file_exists() {
    assert_set_test "compose_file_exists"
    local compose_file
    compose_file=$(get_compose_file "$STACK_NAME")
    assert_file_exists "$compose_file" "databases compose file should exist"
}

test_all_services_defined() {
    assert_set_test "all_services_defined"
    local compose_file
    compose_file=$(get_compose_file "$STACK_NAME")
    for svc in "${SERVICES[@]}"; do
        assert_service_exists "$compose_file" "$svc"
    done
}

test_postgresql_running() {
    assert_set_test "postgresql_running"
    assert_container_running "postgresql"
}

test_postgresql_port() {
    assert_set_test "postgresql_port"
    local ip
    ip=$(get_container_ip "postgresql")
    if [ -n "$ip" ]; then
        assert_port_open "$ip" 5432 "postgresql port 5432 should be open"
    else
        _assert_skip "postgresql port check" "could not determine container IP"
    fi
}

test_redis_running() {
    assert_set_test "redis_running"
    assert_container_running "redis"
}

test_redis_port() {
    assert_set_test "redis_port"
    local ip
    ip=$(get_container_ip "redis")
    if [ -n "$ip" ]; then
        assert_port_open "$ip" 6379 "redis port 6379 should be open"
    else
        _assert_skip "redis port check" "could not determine container IP"
    fi
}

test_redis_ping() {
    assert_set_test "redis_ping"
    local ip
    ip=$(get_container_ip "redis")
    if [ -n "$ip" ]; then
        local response
        response=$(docker exec redis redis-cli ping 2>/dev/null) || true
        assert_eq "$response" "PONG" "redis should respond to PING"
    else
        _assert_skip "redis ping" "could not determine container IP"
    fi
}

test_mariadb_running() {
    assert_set_test "mariadb_running"
    assert_container_running "mariadb"
}

test_mariadb_port() {
    assert_set_test "mariadb_port"
    local ip
    ip=$(get_container_ip "mariadb")
    if [ -n "$ip" ]; then
        assert_port_open "$ip" 3306 "mariadb port 3306 should be open"
    else
        _assert_skip "mariadb port check" "could not determine container IP"
    fi
}

# --- Run ---
setup
for func in $(declare -F | grep -o 'test_' | sort); do
    echo -e "\n${_C_CYAN}▶ ${func}${_C_RESET}"
    $func
done
teardown
