#!/usr/bin/env bash
# sso.test.sh - Tests for SSO stack (authentik-server, authentik-worker)
# Copyright (c) 2026 homelab-stack contributors
# SPDX-License-Identifier: MIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"
source "${SCRIPT_DIR}/../lib/report.sh"

STACK_NAME="sso"

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
    assert_file_exists "$compose_file" "SSO compose file should exist"
}

test_authentik_server_service_defined() {
    assert_set_test "authentik_server_service_defined"
    local compose_file
    compose_file=$(get_compose_file "$STACK_NAME")
    assert_service_exists "$compose_file" "authentik-server"
}

test_authentik_worker_service_defined() {
    assert_set_test "authentik_worker_service_defined"
    local compose_file
    compose_file=$(get_compose_file "$STACK_NAME")
    assert_service_exists "$compose_file" "authentik-worker"
}

test_authentik_server_running() {
    assert_set_test "authentik_server_running"
    assert_container_running "authentik-server"
}

test_authentik_worker_running() {
    assert_set_test "authentik_worker_running"
    assert_container_running "authentik-worker"
}

test_authentik_server_healthy() {
    assert_set_test "authentik_server_healthy"
    assert_container_healthy "authentik-server"
}

test_authentik_http() {
    assert_set_test "authentik_http"
    local ip
    ip=$(get_container_ip "authentik-server")
    if [ -n "$ip" ]; then
        assert_http_status "http://${ip}:9000" 200 "authentik web UI should respond"
    else
        _assert_skip "authentik HTTP check" "could not determine container IP"
    fi
}

# --- Run ---
setup
for func in $(declare -F | grep -o 'test_' | sort); do
    echo -e "\n${_C_CYAN}▶ ${func}${_C_RESET}"
    $func
done
teardown
