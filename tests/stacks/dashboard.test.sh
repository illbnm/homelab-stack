#!/usr/bin/env bash
# dashboard.test.sh - Tests for dashboard stack (homarr)
# Copyright (c) 2026 homelab-stack contributors
# SPDX-License-Identifier: MIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"
source "${SCRIPT_DIR}/../lib/report.sh"

STACK_NAME="dashboard"

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
    assert_file_exists "$compose_file" "dashboard compose file should exist"
}

test_homarr_service_defined() {
    assert_set_test "homarr_service_defined"
    local compose_file
    compose_file=$(get_compose_file "$STACK_NAME")
    assert_service_exists "$compose_file" "homarr"
}

test_homarr_running() {
    assert_set_test "homarr_running"
    assert_container_running "homarr"
}

test_homarr_healthy() {
    assert_set_test "homarr_healthy"
    assert_container_healthy "homarr"
}

test_homarr_http() {
    assert_set_test "homarr_http"
    local ip
    ip=$(get_container_ip "homarr")
    if [ -n "$ip" ]; then
        assert_http_200 "http://${ip}:7575" "homarr web UI should respond"
    else
        _assert_skip "homarr HTTP check" "could not determine container IP"
    fi
}

# --- Run ---
setup
for func in $(declare -F | grep -o 'test_' | sort); do
    echo -e "\n${_C_CYAN}▶ ${func}${_C_RESET}"
    $func
done
teardown
