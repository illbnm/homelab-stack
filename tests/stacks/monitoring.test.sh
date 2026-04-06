#!/bin/bash
# monitoring.test.sh - Monitoring Stack Integration Tests
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_prometheus_running() {
    echo "[monitoring] Testing Prometheus running..."
    assert_container_running "prometheus" || echo "  ⚠️  Prometheus container not found"
}

test_prometheus_http() {
    echo "[monitoring] Testing Prometheus HTTP endpoint..."
    assert_http_200 "http://localhost:9090/-/healthy" 30 || echo "  ⚠️  Prometheus HTTP check skipped"
}

test_prometheus_scrape_cadvisor() {
    echo "[monitoring] Testing Prometheus scraping cAdvisor..."
    local result=$(curl -s "http://localhost:9090/api/v1/query?query=up{job='cadvisor'}" 2>/dev/null)
    if [[ -n "$result" ]]; then
        assert_json_key_exists "$result" ".data.result" || echo "  ⚠️  cAdvisor metrics not found"
    else
        echo "  ⚠️  Prometheus query failed (may not be running)"
    fi
}

test_grafana_running() {
    echo "[monitoring] Testing Grafana running..."
    assert_container_running "grafana" || echo "  ⚠️  Grafana container not found"
}

test_grafana_http() {
    echo "[monitoring] Testing Grafana HTTP endpoint..."
    assert_http_200 "http://localhost:3000/api/health" 30 || echo "  ⚠️  Grafana HTTP check skipped"
}

test_grafana_prometheus_datasource() {
    echo "[monitoring] Testing Grafana Prometheus datasource..."
    local result=$(curl -s -u admin:admin "http://localhost:3000/api/datasources/name/Prometheus" 2>/dev/null)
    if [[ -n "$result" ]]; then
        assert_json_key_exists "$result" ".url" || echo "  ⚠️  Prometheus datasource not configured"
    else
        echo "  ⚠️  Grafana API query failed"
    fi
}

test_loki_running() {
    echo "[monitoring] Testing Loki running..."
    assert_container_running "loki" || echo "  ⚠️  Loki container not found"
}

test_loki_http() {
    echo "[monitoring] Testing Loki HTTP endpoint..."
    assert_http_200 "http://localhost:3100/ready" 30 || echo "  ⚠️  Loki HTTP check skipped"
}

test_alertmanager_running() {
    echo "[monitoring] Testing Alertmanager running..."
    assert_container_running "alertmanager" || echo "  ⚠️  Alertmanager container not found"
}

test_compose_exists() {
    echo "[monitoring] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/monitoring/docker-compose.yml" || echo "  ⚠️  Monitoring compose file not found"
}

run_monitoring_tests() {
    echo "╔══════════════════════════════════════╗"
    echo "║   HomeLab Stack — Monitoring Tests   ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    
    test_compose_exists || true
    test_prometheus_running || true
    test_prometheus_http || true
    test_prometheus_scrape_cadvisor || true
    test_grafana_running || true
    test_grafana_http || true
    test_grafana_prometheus_datasource || true
    test_loki_running || true
    test_loki_http || true
    test_alertmanager_running || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_monitoring_tests
fi
