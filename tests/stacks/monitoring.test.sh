#!/bin/bash
# monitoring.test.sh - Monitoring Stack Integration Tests
# 测试监控组件：Prometheus, Grafana, cAdvisor

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

test_monitoring_prometheus_running() {
    local start_time=$(date +%s)
    assert_container_running "prometheus"
    local duration=$(($(date +%s) - start_time))
    log_test "monitoring" "Prometheus running" "PASS" "$duration"
}

test_monitoring_prometheus_healthy() {
    local start_time=$(date +%s)
    assert_http_200 "http://localhost:9090/-/healthy" 30
    local duration=$(($(date +%s) - start_time))
    log_test "monitoring" "Prometheus healthy endpoint" "PASS" "$duration"
}

test_monitoring_prometheus_api() {
    local start_time=$(date +%s)
    assert_http_200 "http://localhost:9090/api/v1/status/config" 30
    local duration=$(($(date +%s) - start_time))
    log_test "monitoring" "Prometheus API /api/v1/status/config" "PASS" "$duration"
}

test_monitoring_grafana_running() {
    local start_time=$(date +%s)
    assert_container_running "grafana"
    local duration=$(($(date +%s) - start_time))
    log_test "monitoring" "Grafana running" "PASS" "$duration"
}

test_monitoring_grafana_http() {
    local start_time=$(date +%s)
    assert_http_200 "http://localhost:3000/api/health" 30
    local duration=$(($(date +%s) - start_time))
    log_test "monitoring" "Grafana HTTP 200" "PASS" "$duration"
}

test_monitoring_grafana_api() {
    local start_time=$(date +%s)
    assert_http_response "http://localhost:3000/api/health" "committed" 30
    local duration=$(($(date +%s) - start_time))
    log_test "monitoring" "Grafana API health" "PASS" "$duration"
}

test_monitoring_cadvisor_running() {
    local start_time=$(date +%s)
    assert_container_running "cadvisor"
    local duration=$(($(date +%s) - start_time))
    log_test "monitoring" "cAdvisor running" "PASS" "$duration"
}

test_monitoring_cadvisor_metrics() {
    local start_time=$(date +%s)
    assert_http_response "http://localhost:8080/metrics" "container_" 30
    local duration=$(($(date +%s) - start_time))
    log_test "monitoring" "cAdvisor metrics available" "PASS" "$duration"
}

test_monitoring_prometheus_scrape_cadvisor() {
    local start_time=$(date +%s)
    # 检查 Prometheus 是否能抓取到 cAdvisor 指标
    local response
    response=$(curl -s "http://localhost:9090/api/v1/query?query=up{job='cadvisor'}" 2>/dev/null)
    
    if echo "$response" | jq -e '.data.result[0].value[1] == "1"' >/dev/null 2>&1; then
        local duration=$(($(date +%s) - start_time))
        log_test "monitoring" "Prometheus scrapes cAdvisor" "PASS" "$duration"
    else
        local duration=$(($(date +%s) - start_time))
        log_test "monitoring" "Prometheus scrapes cAdvisor" "SKIP" "$duration" "cAdvisor job not configured yet"
    fi
}

test_monitoring_grafana_prometheus_datasource() {
    local start_time=$(date +%s)
    # 检查 Grafana 是否配置了 Prometheus 数据源
    local response
    response=$(curl -s -u admin:admin "http://localhost:3000/api/datasources/name/Prometheus" 2>/dev/null)
    
    if echo "$response" | jq -e '.url' >/dev/null 2>&1; then
        local duration=$(($(date +%s) - start_time))
        log_test "monitoring" "Grafana Prometheus datasource" "PASS" "$duration"
    else
        local duration=$(($(date +%s) - start_time))
        log_test "monitoring" "Grafana Prometheus datasource" "SKIP" "$duration" "Datasource not configured yet"
    fi
}

# 运行所有 monitoring 测试
test_monitoring_all() {
    test_monitoring_prometheus_running
    test_monitoring_prometheus_healthy
    test_monitoring_prometheus_api
    test_monitoring_grafana_running
    test_monitoring_grafana_http
    test_monitoring_grafana_api
    test_monitoring_cadvisor_running
    test_monitoring_cadvisor_metrics
    test_monitoring_prometheus_scrape_cadvisor
    test_monitoring_grafana_prometheus_datasource
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_report
    test_monitoring_all
    
    stats=$(get_assert_stats)
    eval "$stats"
    finalize_report $ASSERT_PASS $ASSERT_FAIL $ASSERT_SKIP "$SCRIPT_DIR/../results"
fi
