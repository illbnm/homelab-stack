#!/usr/bin/env bash
# ai.test.sh - Tests for AI stack (ollama, open-webui)
# Copyright (c) 2026 homelab-stack contributors
# SPDX-License-Identifier: MIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"
source "${SCRIPT_DIR}/../lib/report.sh"

STACK_NAME="ai"
SERVICES=(ollama open-webui)

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
    assert_file_exists "$compose_file" "AI compose file should exist"
}

test_all_services_defined() {
    assert_set_test "all_services_defined"
    local compose_file
    compose_file=$(get_compose_file "$STACK_NAME")
    for svc in "${SERVICES[@]}"; do
        assert_service_exists "$compose_file" "$svc"
    done
}

test_ollama_running() {
    assert_set_test "ollama_running"
    assert_container_running "ollama"
}

test_ollama_version_api() {
    assert_set_test "ollama_version_api"
    local ip
    ip=$(get_container_ip "ollama")
    if [ -n "$ip" ]; then
        local response
        response=$(curl -sf --max-time 10 "http://${ip}:11434/api/version" 2>/dev/null) || true
        assert_no_errors "$response"
    else
        _assert_skip "ollama version API" "could not determine container IP"
    fi
}

test_open_webui_running() {
    assert_set_test "open_webui_running"
    assert_container_running "open-webui"
}

test_open_webui_http() {
    assert_set_test "open_webui_http"
    local ip
    ip=$(get_container_ip "open-webui")
    if [ -n "$ip" ]; then
        assert_http_200 "http://${ip}:3000" "open-webui should respond"
    else
        _assert_skip "open-webui HTTP check" "could not determine container IP"
    fi
}

# --- Run ---
setup
for func in $(declare -F | grep -o 'test_' | sort); do
    echo -e "\n${_C_CYAN}▶ ${func}${_C_RESET}"
    $func
done
teardown
