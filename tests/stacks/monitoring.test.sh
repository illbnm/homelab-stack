#!/usr/bin/env bash
# monitoring.test.sh - Tests for monitoring stack (prometheus, grafana, loki, alertmanager, cadvisor, node-exporter)
# Copyright (c) 2026 homelab-stack contributors
# SPDX-License-Identifier: MIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"
source "${SCRIPT_DIR}/../lib/report.sh"

STACK_NAME="monitoring"
SERVICES=(prometheus grafana loki alertmanager cadvisor node-exporter)

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
    assert_file_exists "$compose_file" "monitoring compose file should exist"
}

test_all_services_defined() {
    assert_set_test "all_services_defined"
    local compose_file
    compose_file=$(get_compose_file "$STACK_NAME")
    for svc in "${SERVICES[@]}"; do
        assert_service_exists "$compose_file" "$svc"
    done
}

test_prometheus_running() {
    assert_set_test "prometheus_running"
    assert_container_running "prometheus"
}

test_prometheus_healthy() {
    assert_set_test "prometheus_healthy"
    assert_container_healthy "prometheus"
}

test_prometheus_http() {
    assert_set_test "prometheus_http"
    local ip
    ip=$(get_container_ip "prometheus")
    if [ -n "$ip" ]; then
        assert_http_200 "http://${ip}:9090/-/healthy" "prometheus healthy endpoint should respond 200"
    else
        _assert_skip "prometheus HTTP check" "could not determine container IP"
    fi
}

test_grafana_running() {
    assert_set_test "grafana_running"
    assert_container_running "grafana"
}

test_grafana_http() {
    assert_set_test "grafana_http"
    local ip
    ip=$(get_container_ip "grafana")
    if [ -n "$ip" ]; then
        assert_http_200 "http://${ip}:3000" "grafana web UI should respond"
    else
        _assert_skip "grafana HTTP check" "could not determine container IP"
    fi
}

test_loki_running() {
    assert_set_test "loki_running"
    assert_container_running "loki"
}

test_alertmanager_running() {
    assert_set_test "alertmanager_running"
    assert_container_running "alertmanager"
}

test_cadvisor_running() {
    assert_set_test "cadvisor_running"
    assert_container_running "cadvisor"
}

test_node_exporter_running() {
    assert_set_test "node_exporter_running"
    assert_container_running "node-exporter"
}

# --- Run ---
setup
for func in $(declare -F | grep -o 'test_' | sort); do
    echo -e "\n${_C_CYAN}▶ ${func}${_C_RESET}"
    $func
done
teardown
