#!/usr/bin/env bash
# notifications.test.sh - Tests for notifications stack (ntfy, gotify)
# Copyright (c) 2026 homelab-stack contributors
# SPDX-License-Identifier: MIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"
source "${SCRIPT_DIR}/../lib/report.sh"

STACK_NAME="notifications"
SERVICES=(ntfy gotify)

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
    assert_file_exists "$compose_file" "notifications compose file should exist"
}

test_all_services_defined() {
    assert_set_test "all_services_defined"
    local compose_file
    compose_file=$(get_compose_file "$STACK_NAME")
    for svc in "${SERVICES[@]}"; do
        assert_service_exists "$compose_file" "$svc"
    done
}

test_ntfy_running() {
    assert_set_test "ntfy_running"
    assert_container_running "ntfy"
}

test_ntfy_http() {
    assert_set_test "ntfy_http"
    local ip
    ip=$(get_container_ip "ntfy")
    if [ -n "$ip" ]; then
        assert_http_200 "http://${ip}:80/v1/health" "ntfy health endpoint should respond"
    else
        _assert_skip "ntfy HTTP check" "could not determine container IP"
    fi
}

test_gotify_running() {
    assert_set_test "gotify_running"
    assert_container_running "gotify"
}

test_gotify_http() {
    assert_set_test "gotify_http"
    local ip
    ip=$(get_container_ip "gotify")
    if [ -n "$ip" ]; then
        assert_http_200 "http://${ip}:8080" "gotify web UI should respond"
    else
        _assert_skip "gotify HTTP check" "could not determine container IP"
    fi
}

# --- Run ---
setup
for func in $(declare -F | grep -o 'test_' | sort); do
    echo -e "\n${_C_CYAN}▶ ${func}${_C_RESET}"
    $func
done
teardown
