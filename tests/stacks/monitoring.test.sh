#!/usr/bin/env bash
# =============================================================================
# Monitoring Stack Tests (Prometheus, Grafana, Loki, Alertmanager)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.."; pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/report.sh"

STACK_NAME="monitoring"
[[ -f "$BASE_DIR/.env" ]] && source "$BASE_DIR/.env" 2>/dev/null || true

test_prometheus_running() {
    local start=$(date +%s)
    assert_container_running "prometheus" "Prometheus running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "prometheus_running" "$?" "$duration" "$STACK_NAME"
}

test_grafana_running() {
    local start=$(date +%s)
    assert_container_running "grafana" "Grafana running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "grafana_running" "$?" "$duration" "$STACK_NAME"
}

test_loki_running() {
    local start=$(date +%s)
    assert_container_running "loki" "Loki running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "loki_running" "$?" "$duration" "$STACK_NAME"
}

test_alertmanager_running() {
    local start=$(date +%s)
    assert_container_running "alertmanager" "Alertmanager running"
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "alertmanager_running" "$?" "$duration" "$STACK_NAME"
}

test_prometheus_healthy() {
    local start=$(date +%s)
    assert_container_healthy "prometheus" 60
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "prometheus_healthy" "$?" "$duration" "$STACK_NAME"
}

test_prometheus_health_endpoint() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:9090/-/healthy" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "prometheus_health" "$?" "$duration" "$STACK_NAME"
}

test_grafana_health() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:3000/api/health" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "grafana_health" "$?" "$duration" "$STACK_NAME"
}

test_alertmanager_health() {
    local start=$(date +%s)
    assert_http_200 "http://localhost:9093/-/healthy" 30
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "alertmanager_health" "$?" "$duration" "$STACK_NAME"
}

test_prometheus_metrics_endpoint() {
    local start=$(date +%s)
    assert_http_response "http://localhost:9090/metrics" "prometheus" 15
    local duration=$(echo "$(date +%s) - $start" | bc)
    report_add_result "prometheus_metrics" "$?" "$duration" "$STACK_NAME"
}

run_monitoring_tests() {
    report_init
    report_stack "Monitoring Stack"

    test_prometheus_running
    test_grafana_running
    test_loki_running
    test_alertmanager_running
    test_prometheus_healthy
    test_prometheus_health_endpoint
    test_grafana_health
    test_alertmanager_health
    test_prometheus_metrics_endpoint

    local duration=$(echo "$(date +%s) - $REPORT_START_TIME" | bc)
    report_summary $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
    report_export_json $TESTS_PASSED $TESTS_FAILED $TESTS_SKIPPED "$duration"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_monitoring_tests
fi
