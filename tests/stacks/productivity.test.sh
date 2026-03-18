#!/usr/bin/env bash
# productivity.test.sh - Tests for productivity stack (gitea, vaultwarden, outline, bookstack)
# Copyright (c) 2026 homelab-stack contributors
# SPDX-License-Identifier: MIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"
source "${SCRIPT_DIR}/../lib/report.sh"

STACK_NAME="productivity"
SERVICES=(gitea vaultwarden outline bookstack)

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
    assert_file_exists "$compose_file" "productivity compose file should exist"
}

test_all_services_defined() {
    assert_set_test "all_services_defined"
    local compose_file
    compose_file=$(get_compose_file "$STACK_NAME")
    for svc in "${SERVICES[@]}"; do
        assert_service_exists "$compose_file" "$svc"
    done
}

test_gitea_running() {
    assert_set_test "gitea_running"
    assert_container_running "gitea"
}

test_gitea_version_api() {
    assert_set_test "gitea_version_api"
    local ip
    ip=$(get_container_ip "gitea")
    if [ -n "$ip" ]; then
        local response
        response=$(curl -sf --max-time 10 "http://${ip}/api/v1/version" 2>/dev/null) || true
        assert_json_key_exists "$response" ".version" "gitea version API should return version"
    else
        _assert_skip "gitea version API" "could not determine container IP"
    fi
}

test_vaultwarden_running() {
    assert_set_test "vaultwarden_running"
    assert_container_running "vaultwarden"
}

test_outline_running() {
    assert_set_test "outline_running"
    assert_container_running "outline"
}

test_bookstack_running() {
    assert_set_test "bookstack_running"
    assert_container_running "bookstack"
}

# --- Run ---
setup
for func in $(declare -F | grep -o 'test_' | sort); do
    echo -e "\n${_C_CYAN}▶ ${func}${_C_RESET}"
    $func
done
teardown
