#!/usr/bin/env bash
# storage.test.sh - Tests for storage stack (nextcloud)
# Copyright (c) 2026 homelab-stack contributors
# SPDX-License-Identifier: MIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"
source "${SCRIPT_DIR}/../lib/report.sh"

STACK_NAME="storage"

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
    assert_file_exists "$compose_file" "storage compose file should exist"
}

test_nextcloud_service_defined() {
    assert_set_test "nextcloud_service_defined"
    local compose_file
    compose_file=$(get_compose_file "$STACK_NAME")
    assert_service_exists "$compose_file" "nextcloud"
}

test_nextcloud_running() {
    assert_set_test "nextcloud_running"
    assert_container_running "nextcloud"
}

test_nextcloud_healthy() {
    assert_set_test "nextcloud_healthy"
    assert_container_healthy "nextcloud"
}

test_nextcloud_status_endpoint() {
    assert_set_test "nextcloud_status_endpoint"
    local ip
    ip=$(get_container_ip "nextcloud")
    if [ -n "$ip" ]; then
        local response
        response=$(curl -sfk --max-time 10 "https://${ip}:443/status.php" 2>/dev/null) || true
        assert_json_value "$response" ".installed" "true" "nextcloud should be installed"
    else
        _assert_skip "nextcloud status endpoint" "could not determine container IP"
    fi
}

test_nextcloud_maintenance_off() {
    assert_set_test "nextcloud_maintenance_off"
    local ip
    ip=$(get_container_ip "nextcloud")
    if [ -n "$ip" ]; then
        local response
        response=$(curl -sfk --max-time 10 "https://${ip}:443/status.php" 2>/dev/null) || true
        assert_json_value "$response" ".maintenance" "false" "nextcloud should not be in maintenance mode"
    else
        _assert_skip "nextcloud maintenance check" "could not determine container IP"
    fi
}

# --- Run ---
setup
for func in $(declare -F | grep -o 'test_' | sort); do
    echo -e "\n${_C_CYAN}▶ ${func}${_C_RESET}"
    $func
done
teardown
