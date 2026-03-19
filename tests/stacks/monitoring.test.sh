#!/bin/bash
# monitoring.test.sh - Monitoring Stack 集成测试
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_grafana_running() {
    echo "[monitoring] Testing Grafana running..."
    assert_container_running "grafana"
}

test_grafana_http() {
    echo "[monitoring] Testing Grafana HTTP..."
    assert_http_200 "http://localhost:3000/api/health" 30
}

test_prometheus_running() {
    echo "[monitoring] Testing Prometheus running..."
    assert_container_running "prometheus"
}

test_prometheus_http() {
    echo "[monitoring] Testing Prometheus HTTP..."
    assert_http_200 "http://localhost:9090/-/healthy" 30
}

test_prometheus_scrape_cadvisor() {
    echo "[monitoring] Testing Prometheus scrape cAdvisor..."
    local result=$(curl -s "http://localhost:9090/api/v1/query?query=up{job='cadvisor'}" 2>/dev/null)
    local status=$(echo "$result" | jq -r '.data.result[0].value[1]' 2>/dev/null)
    if [[ "$status" == "1" ]]; then
        echo -e "${GREEN}✅ PASS${NC} cAdvisor metrics scraped"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} cAdvisor not being scraped"
        return 1
    fi
}

test_alertmanager_running() {
    echo "[monitoring] Testing Alertmanager running..."
    assert_container_running "alertmanager" || return 0  # Optional
}

test_alertmanager_http() {
    echo "[monitoring] Testing Alertmanager HTTP..."
    assert_http_200 "http://localhost:9093/-/healthy" 30 || return 0
}

test_cadvisor_running() {
    echo "[monitoring] Testing cAdvisor running..."
    assert_container_running "cadvisor"
}

test_cadvisor_http() {
    echo "[monitoring] Testing cAdvisor HTTP..."
    assert_http_200 "http://localhost:8080" 30
}

test_nodeexporter_running() {
    echo "[monitoring] Testing Node Exporter running..."
    assert_container_running "nodeexporter"
}

test_nodeexporter_http() {
    echo "[monitoring] Testing Node Exporter HTTP..."
    assert_http_200 "http://localhost:9100/metrics" 30
}

test_compose_exists() {
    echo "[monitoring] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/monitoring/docker-compose.yml"
}

run_monitoring_tests() {
    print_header "HomeLab Stack — Monitoring Tests"
    
    test_compose_exists || true
    test_grafana_running || true
    test_grafana_http || true
    test_prometheus_running || true
    test_prometheus_http || true
    test_prometheus_scrape_cadvisor || true
    test_alertmanager_running || true
    test_alertmanager_http || true
    test_cadvisor_running || true
    test_cadvisor_http || true
    test_nodeexporter_running || true
    test_nodeexporter_http || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_monitoring_tests
fi
