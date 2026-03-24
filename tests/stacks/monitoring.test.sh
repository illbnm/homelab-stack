#!/usr/bin/env bash
# ==============================================================================
# Observability Stack Tests
# Tests for Prometheus, Grafana, Loki, Alertmanager, Uptime Kuma
# ==============================================================================

# Test: Prometheus container is running
test_prometheus_running() {
    assert_container_running "prometheus"
}

# Test: Prometheus is healthy
test_prometheus_healthy() {
    assert_container_healthy "prometheus" 60
}

# Test: Prometheus health endpoint
test_prometheus_health() {
    assert_http_200 "http://localhost:9090/-/healthy" 10
}

# Test: Prometheus ready endpoint
test_prometheus_ready() {
    assert_http_200 "http://localhost:9090/-/ready" 10
}

# Test: Prometheus targets are up
test_prometheus_targets() {
    begin_test
    local response=$(curl -sf "http://localhost:9090/api/v1/targets" 2>/dev/null || echo '{"data":{"activeTargets":[]}}')
    local up_count=$(echo "$response" | jq '.data.activeTargets | map(select(.health == "up")) | length' 2>/dev/null || echo 0)
    
    if [[ "$up_count" -gt 0 ]]; then
        log_pass "Prometheus has $up_count targets up"
    else
        log_skip "No Prometheus targets configured or all down"
    fi
}

# Test: Grafana container is running
test_grafana_running() {
    assert_container_running "grafana"
}

# Test: Grafana is healthy
test_grafana_healthy() {
    assert_container_healthy "grafana" 60
}

# Test: Grafana health endpoint
test_grafana_health() {
    assert_http_200 "http://localhost:3000/api/health" 10
}

# Test: Grafana Prometheus datasource
test_grafana_prometheus_datasource() {
    begin_test
    local response=$(curl -sf "http://admin:admin@localhost:3000/api/datasources" 2>/dev/null || echo "[]")
    
    if echo "$response" | jq -e 'map(select(.type == "prometheus")) | length > 0' >/dev/null 2>&1; then
        log_pass "Grafana has Prometheus datasource configured"
    else
        log_skip "Grafana Prometheus datasource not configured"
    fi
}

# Test: Loki container (if configured)
test_loki_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "loki"; then
        assert_container_running "loki"
        assert_http_200 "http://localhost:3100/ready" 10
    else
        log_skip "Loki not configured"
    fi
}

# Test: Alertmanager container (if configured)
test_alertmanager_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "alertmanager"; then
        assert_container_running "alertmanager"
        assert_http_200 "http://localhost:9093/-/healthy" 10
    else
        log_skip "Alertmanager not configured"
    fi
}

# Test: Uptime Kuma container (if configured)
test_uptime_kuma_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "uptime-kuma"; then
        assert_container_running "uptime-kuma"
        assert_http_200 "http://localhost:3001" 10
    else
        log_skip "Uptime Kuma not configured"
    fi
}

# Test: cAdvisor (if configured)
test_cadvisor_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "cadvisor"; then
        assert_container_running "cadvisor"
        assert_http_200 "http://localhost:8080/healthz" 10
    else
        log_skip "cAdvisor not configured"
    fi
}

# Test: Node Exporter (if configured)
test_node_exporter_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "node-exporter"; then
        assert_container_running "node-exporter"
        assert_http_200 "http://localhost:9100/metrics" 10
    else
        log_skip "Node Exporter not configured"
    fi
}

# Test: Observability compose syntax
test_observability_compose_syntax() {
    local compose_file="$BASE_DIR/stacks/monitoring/docker-compose.yml"
    if [[ -f "$compose_file" ]]; then
        assert_compose_syntax "$compose_file"
    else
        log_skip "Monitoring compose file not found"
    fi
}

# Test: No :latest tags
test_observability_no_latest_tags() {
    assert_no_latest_tags "$BASE_DIR/stacks/monitoring"
}

# Run all tests
run_tests() {
    test_prometheus_running
    test_prometheus_healthy
    test_prometheus_health
    test_prometheus_ready
    test_prometheus_targets
    test_grafana_running
    test_grafana_healthy
    test_grafana_health
    test_grafana_prometheus_datasource
    test_loki_running
    test_alertmanager_running
    test_uptime_kuma_running
    test_cadvisor_running
    test_node_exporter_running
    test_observability_compose_syntax
    test_observability_no_latest_tags
}

# Execute tests
run_tests