#!/usr/bin/env bash
# network.test.sh - Tests for network stack (adguard-home)
# Copyright (c) 2026 homelab-stack contributors
# SPDX-License-Identifier: MIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"
source "${SCRIPT_DIR}/../lib/report.sh"

STACK_NAME="network"

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
    assert_file_exists "$compose_file" "network compose file should exist"
}

test_adguard_service_defined() {
    assert_set_test "adguard_service_defined"
    local compose_file
    compose_file=$(get_compose_file "$STACK_NAME")
    assert_service_exists "$compose_file" "adguard-home" || \
    assert_service_exists "$compose_file" "adguard"
}

test_adguard_running() {
    assert_set_test "adguard_running"
    assert_container_running "adguard-home" || \
    assert_container_running "adguard"
}

test_adguard_http() {
    assert_set_test "adguard_http"
    local container="adguard-home"
    docker ps --format '{{.Names}}' | grep -qx "adguard" && container="adguard"
    local ip
    ip=$(get_container_ip "$container")
    if [ -n "$ip" ]; then
        assert_http_200 "http://${ip}:3000" "adguard web UI should respond"
    else
        _assert_skip "adguard HTTP check" "could not determine container IP"
    fi
}

test_adguard_dns_port() {
    assert_set_test "adguard_dns_port"
    local container="adguard-home"
    docker ps --format '{{.Names}}' | grep -qx "adguard" && container="adguard"
    local ip
    ip=$(get_container_ip "$container")
    if [ -n "$ip" ]; then
        assert_port_open "$ip" 53 "adguard DNS port 53 should be open"
    else
        _assert_skip "adguard DNS port check" "could not determine container IP"
    fi
}

# --- Run ---
setup
for func in $(declare -F | grep -o 'test_' | sort); do
    echo -e "\n${_C_CYAN}▶ ${func}${_C_RESET}"
    $func
done
teardown
