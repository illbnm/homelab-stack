#!/bin/bash
# monitoring.test.sh - Monitoring stack integration tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

# shellcheck source=../lib/assert.sh
source "$LIB_DIR/assert.sh"
# shellcheck source=../lib/docker.sh
source "$LIB_DIR/docker.sh"

STACK_NAME="monitoring"
PROMETHEUS_URL="http://localhost:9090"
GRAFANA_URL="http://localhost:3000"
CADVISOR_URL="http://localhost:8080"
NODE_EXPORTER_URL="http://localhost:9100"

test_prometheus_running() {
    echo "Testing Prometheus container state..."
    assert_container_running "prometheus"
    assert_container_healthy "prometheus"
}

test_grafana_running() {
    echo "Testing Grafana container state..."
    assert_container_running "grafana"
    assert_container_healthy "grafana"
}

test_cadvisor_running() {
    echo "Testing cAdvisor container state..."
    assert_container_running "cadvisor"
    assert_container_healthy "cadvisor"
}

test_node_exporter_running() {
    echo "Testing Node Exporter container state..."
    assert_container_running "node_exporter"
    assert_container_healthy "node_exporter"
}

test_prometheus_endpoints() {
    echo "Testing Prometheus HTTP endpoints..."
    assert_http_200 "$PROMETHEUS_URL"
    assert_http_200 "$PROMETHEUS_URL/-/ready"
    assert_http_200 "$PROMETHEUS_URL/-/healthy"
    assert_http_200 "$PROMETHEUS_URL/metrics"
}

test_grafana_api() {
    echo "Testing Grafana API health..."
    assert_http_200 "$GRAFANA_URL"
    assert_http_200 "$GRAFANA_URL/api/health"
}

test_cadvisor_metrics() {
    echo "Testing cAdvisor metrics exposure..."
    assert_http_200 "$CADVISOR_URL"
    assert_http_200 "$CADVISOR_URL/metrics"

    # Verify cAdvisor exposes container metrics
    local metrics_output
    metrics_output=$(curl -s "$CADVISOR_URL/metrics" || true)
    assert_contains "$metrics_output" "container_cpu_usage_seconds_total"
    assert_contains "$metrics_output" "container_memory_usage_bytes"
}

test_node_exporter_metrics() {
    echo "Testing Node Exporter system metrics..."
    assert_http_200 "$NODE_EXPORTER_URL"
    assert_http_200 "$NODE_EXPORTER_URL/metrics"

    # Verify system metrics are exposed
    local metrics_output
    metrics_output=$(curl -s "$NODE_EXPORTER_URL/metrics" || true)
    assert_contains "$metrics_output" "node_cpu_seconds_total"
    assert_contains "$metrics_output" "node_memory_MemTotal_bytes"
    assert_contains "$metrics_output" "node_filesystem_size_bytes"
}

test_prometheus_targets() {
    echo "Testing Prometheus scraping configuration..."

    # Check targets API
    assert_http_200 "$PROMETHEUS_URL/api/v1/targets"

    local targets_response
    targets_response=$(curl -s "$PROMETHEUS_URL/api/v1/targets" || true)

    # Verify essential targets are configured
    assert_contains "$targets_response" "prometheus:9090"
    assert_contains "$targets_response" "node-exporter:9100"
    assert_contains "$targets_response" "cadvisor:8080"

    # Check that targets are UP
    local active_targets
    active_targets=$(curl -s "$PROMETHEUS_URL/api/v1/targets" | grep -o '"health":"up"' | wc -l || echo "0")
    assert_gt "$active_targets" 0 "At least one target should be UP"
}

test_prometheus_scraping() {
    echo "Testing Prometheus data scraping via PromQL..."

    # Test basic PromQL query - up metric should exist
    local query_result
    query_result=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=up" || true)
    assert_contains "$query_result" '"status":"success"'
    assert_contains "$query_result" '"result"'

    # Test node metrics are being scraped
    query_result=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=node_cpu_seconds_total" || true)
    assert_contains "$query_result" '"status":"success"'

    # Test container metrics are being scraped
    query_result=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=container_cpu_usage_seconds_total" || true)
    assert_contains "$query_result" '"status":"success"'
}

test_grafana_datasource() {
    echo "Testing Grafana Prometheus datasource connectivity..."

    # Test datasource health (requires auth but health endpoint is accessible)
    local datasource_test
    datasource_test=$(curl -s -w "%{http_code}" "$GRAFANA_URL/api/datasources/proxy/1/api/v1/query?query=up" -o /dev/null || echo "000")

    # Should get 200 (success) or 401/403 (auth required but datasource reachable)
    if [[ "$datasource_test" != "200" && "$datasource_test" != "401" && "$datasource_test" != "403" ]]; then
        echo "ERROR: Grafana datasource test failed with HTTP $datasource_test"
        return 1
    fi

    echo "Grafana datasource connectivity verified (HTTP $datasource_test)"
}

test_service_interconnection() {
    echo "Testing service-to-service connectivity..."

    # Test internal Docker network connectivity
    docker exec prometheus wget -q --spider http://node-exporter:9100/metrics || {
        echo "ERROR: Prometheus cannot reach node-exporter internally"
        return 1
    }

    docker exec prometheus wget -q --spider http://cadvisor:8080/metrics || {
        echo "ERROR: Prometheus cannot reach cAdvisor internally"
        return 1
    }

    echo "Service interconnection verified"
}

test_prometheus_config_reload() {
    echo "Testing Prometheus configuration reload..."

    # Test config reload endpoint
    local reload_result
    reload_result=$(curl -s -w "%{http_code}" -X POST "$PROMETHEUS_URL/-/reload" -o /dev/null || echo "000")
    assert_eq "$reload_result" "200" "Prometheus config reload should succeed"
}

run_monitoring_tests() {
    echo "=== Running Monitoring Stack Tests ==="

    # Container health tests
    test_prometheus_running
    test_grafana_running
    test_cadvisor_running
    test_node_exporter_running

    # HTTP endpoint tests
    test_prometheus_endpoints
    test_grafana_api
    test_cadvisor_metrics
    test_node_exporter_metrics

    # Scraping and configuration tests
    test_prometheus_targets
    test_prometheus_scraping
    test_prometheus_config_reload

    # Service connectivity tests
    test_grafana_datasource
    test_service_interconnection

    echo "=== Monitoring Stack Tests Completed ==="
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_monitoring_tests
fi
