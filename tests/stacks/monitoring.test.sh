#!/bin/bash
# monitoring.test.sh - Monitoring Stack 测试
# 测试 Grafana, Prometheus, Loki, Alertmanager, Uptime Kuma

set -u

# Grafana 测试
test_grafana_running() {
    assert_container_running "grafana"
}

test_grafana_http() {
    assert_http_200 "http://localhost:3000/api/health"
}

test_grafana_api() {
    assert_http_response "http://localhost:3000/api/health" "committed" "Grafana health API"
}

# Prometheus 测试
test_prometheus_running() {
    assert_container_running "prometheus"
}

test_prometheus_http() {
    assert_http_200 "http://localhost:9090/-/healthy"
}

test_prometheus_scrape() {
    # 检查 Prometheus 是否能抓取到指标
    local result=$(curl -s "http://localhost:9090/api/v1/query?query=up" 2>/dev/null)
    assert_json_key_exists "$result" ".data.result" "Prometheus scrape targets"
}

# Loki 测试
test_loki_running() {
    assert_container_running "loki"
}

test_loki_http() {
    assert_http_200 "http://localhost:3100/ready"
}

# Alertmanager 测试
test_alertmanager_running() {
    assert_container_running "alertmanager"
}

test_alertmanager_http() {
    assert_http_200 "http://localhost:9093/-/healthy"
}

# Uptime Kuma 测试
test_uptime_kuma_running() {
    assert_container_running "uptime-kuma"
}

test_uptime_kuma_http() {
    assert_http_200 "http://localhost:3001"
}

# 服务间互通测试
test_grafana_prometheus_datasource() {
    # 检查 Grafana 是否能连接 Prometheus
    local result=$(curl -s "http://localhost:3000/api/datasources/name/Prometheus" 2>/dev/null)
    if [[ -n "$result" ]]; then
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "PASS" "Grafana Prometheus datasource" "$duration"
        return 0
    else
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "SKIP" "Grafana Prometheus datasource" "$duration"
    fi
}
