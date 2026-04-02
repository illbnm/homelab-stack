#!/usr/bin/env bash
# Monitoring Stack Tests - HomeLab Stack Integration Tests

set -euo pipefail

# 导入依赖
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

STACK_NAME="monitoring"

# Prometheus 测试
test_prometheus_running() {
    assert_container_running "prometheus" "Prometheus container should be running"
}

test_prometheus_healthy() {
    assert_container_healthy "prometheus" 60 "Prometheus container should be healthy"
}

test_prometheus_api() {
    assert_http_200 "http://localhost:9090/-/healthy" 30 "Prometheus health endpoint should be accessible"
}

test_prometheus_ready() {
    assert_http_200 "http://localhost:9090/-/ready" 30 "Prometheus ready endpoint should be accessible"
}

test_prometheus_config() {
    assert_http_response "http://localhost:9090/api/v1/status/config" "\"success\"" "Prometheus config should be loaded"
}

# Grafana 测试
test_grafana_running() {
    assert_container_running "grafana" "Grafana container should be running"
}

test_grafana_healthy() {
    assert_container_healthy "grafana" 60 "Grafana container should be healthy"
}

test_grafana_api() {
    assert_http_200 "http://localhost:3000/api/health" 30 "Grafana health endpoint should be accessible"
}

test_grafana_prometheus_datasource() {
    local result
    result=$(curl -s -u "admin:${GRAFANA_ADMIN_PASSWORD:-admin}" \
        "http://localhost:3000/api/datasources/name/Prometheus" 2>/dev/null || echo "{}")

    assert_json_key_exists "$result" ".url" "Grafana should have Prometheus datasource configured"
}

# cAdvisor 测试
test_cadvisor_running() {
    assert_container_running "cadvisor" "cAdvisor container should be running"
}

test_cadvisor_api() {
    assert_http_200 "http://localhost:8080/healthz" 30 "cAdvisor health endpoint should be accessible"
}

test_prometheus_scrape_cadvisor() {
    local result
    result=$(curl -s "http://localhost:9090/api/v1/query?query=up{job=\"cadvisor\"}" 2>/dev/null || echo "{}")

    assert_json_value "$result" ".data.result[0].value[1]" "1" "Prometheus should scrape cAdvisor metrics"
}

# Node Exporter 测试
test_node_exporter_running() {
    if container_exists "node-exporter"; then
        assert_container_running "node-exporter" "Node Exporter container should be running"
    else
        echo -e "${YELLOW}⏭️  SKIP${NC}: Node Exporter not configured"
        ((TESTS_SKIPPED++))
    fi
}

# Alertmanager 测试
test_alertmanager_running() {
    if container_exists "alertmanager"; then
        assert_container_running "alertmanager" "Alertmanager container should be running"
        assert_http_200 "http://localhost:9093/-/healthy" 30 "Alertmanager health endpoint should be accessible"
    else
        echo -e "${YELLOW}⏭️  SKIP${NC}: Alertmanager not configured"
        ((TESTS_SKIPPED++))
    fi
}

# Loki 测试
test_loki_running() {
    if container_exists "loki"; then
        assert_container_running "loki" "Loki container should be running"
        assert_http_200 "http://localhost:3100/ready" 30 "Loki ready endpoint should be accessible"
    else
        echo -e "${YELLOW}⏭️  SKIP${NC}: Loki not configured"
        ((TESTS_SKIPPED++))
    fi
}

# 配置完整性测试
test_compose_syntax() {
    echo "Testing compose file syntax..."
    docker compose -f "stacks/$STACK_NAME/docker-compose.yml" config --quiet 2>&1
    assert_exit_code $? "Monitoring stack compose file syntax is valid"
}

test_no_latest_tags() {
    assert_no_latest_images "stacks/$STACK_NAME" "Monitoring stack should not use :latest image tags"
}

# 主测试运行器
run_monitoring_tests() {
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║   Testing Stack: Monitoring          ║"
    echo "╚══════════════════════════════════════╝"
    echo ""

    local start_time
    start_time=$(date +%s)

    # 运行所有测试
    test_compose_syntax || true
    test_no_latest_tags || true

    test_prometheus_running || true
    test_prometheus_healthy || true
    test_prometheus_api || true
    test_prometheus_ready || true
    test_prometheus_config || true

    test_grafana_running || true
    test_grafana_healthy || true
    test_grafana_api || true
    test_grafana_prometheus_datasource || true

    test_cadvisor_running || true
    test_cadvisor_api || true
    test_prometheus_scrape_cadvisor || true

    test_node_exporter_running || true
    test_alertmanager_running || true
    test_loki_running || true

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    echo "──────────────────────────────────────"
    echo "Monitoring Stack Tests Complete"
    echo "Passed: $TESTS_PASSED | Failed: $TESTS_FAILED | Skipped: $TESTS_SKIPPED"
    echo "Duration: ${duration}s"
    echo "──────────────────────────────────────"
}

# 如果直接运行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_monitoring_tests
fi
