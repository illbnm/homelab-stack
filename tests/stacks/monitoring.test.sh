#!/usr/bin/env bash
# =============================================================================
# Monitoring Stack Integration Tests
# Tests: Prometheus, Grafana, Loki, Alertmanager
# =============================================================================

STACK_NAME="monitoring"

# =============================================================================
# Container Health Tests
# =============================================================================

test_prometheus_running() {
  assert_container_running "prometheus" "Prometheus should be running"
  assert_container_healthy "prometheus" "Prometheus should be healthy within 60s"
}

test_grafana_running() {
  assert_container_running "grafana" "Grafana should be running"
  assert_container_healthy "grafana" "Grafana should be healthy within 60s"
}

test_loki_running() {
  assert_container_running "loki" "Loki should be running"
  assert_container_healthy "loki" "Loki should be healthy within 60s"
}

test_alertmanager_running() {
  assert_container_running "alertmanager" "Alertmanager should be running"
  assert_container_healthy "alertmanager" "Alertmanager should be healthy within 60s"
}

test_cadvisor_running() {
  assert_container_running "cadvisor" "cAdvisor should be running"
}

test_node_exporter_running() {
  assert_container_running "node-exporter" "Node Exporter should be running"
}

# =============================================================================
# HTTP Endpoint Tests
# =============================================================================

test_prometheus_api() {
  assert_http_200 "http://localhost:9090/-/healthy" "Prometheus health endpoint should be accessible"
}

test_grafana_api() {
  assert_http_200 "http://localhost:3000/api/health" "Grafana health endpoint should be accessible"
}

test_loki_api() {
  assert_http_200 "http://localhost:3100/ready" "Loki ready endpoint should be accessible"
}

test_alertmanager_api() {
  assert_http_200 "http://localhost:9093/-/healthy" "Alertmanager health endpoint should be accessible"
}

test_grafana_datasource() {
  local result
  result=$(curl -sf -u admin:${GRAFANA_ADMIN_PASSWORD:-changeme "http://localhost:3000/api/datasources/name/Prometheus")
  
  assert_json_key_exists "$result" ".url"
  assert_json_value "$result" ".type" "prometheus"
}

# =============================================================================
# Prometheus Targets Tests
# =============================================================================

test_prometheus_targets() {
  local targets
  targets=$(curl -sf "http://localhost:9090/api/v1/targets")
  
  # Check all critical targets are UP
  local up_count
  up_count=$(echo "$targets" | jq -r '.data.activeTargets | map(select(.health == "up") | length')
  
  assert_eq "$up_count" "5" "At least 5 Prometheus targets should be UP"
}

test_prometheus_scrape_cadvisor() {
  local result
  result=$(curl -sf "http://localhost:9090/api/v1/query?query=up{job='cadvisor'}")
  
  assert_json_value "$result" ".data.result[0].value[1]" "1"
}

test_prometheus_scrape_node_exporter() {
  local result
  result=$(curl -sf "http://localhost:9090/api/v1/query?query=up{job='node-exporter'}")
  
  assert_json_value "$result" ".data.result[0].value[1]" "1"
}

# =============================================================================
# Alertmanager Tests
# =============================================================================

test_alertmanager_config() {
  assert_http_200 "http://localhost:9093/api/v2/status" "Alertmanager status endpoint should be accessible"
}

test_alertmanager_receivers() {
  local result
  result=$(curl -sf "http://localhost:9093/api/v2/receivers")
  
  local receiver_count
  receiver_count=$(echo "$result" | jq -r 'length')
  
  assert_not_empty "$receiver_count" "Alertmanager should have receivers configured"
}

# =============================================================================
# Run Tests
# =============================================================================

run_all_tests() {
  echo "Running Container Health Tests..."
  test_prometheus_running
  test_grafana_running
  test_loki_running
  test_alertmanager_running
  test_cadvisor_running
  test_node_exporter_running
  
  echo ""
  echo "Running HTTP Endpoint Tests..."
  test_prometheus_api
  test_grafana_api
  test_loki_api
  test_alertmanager_api
  test_grafana_datasource
  
  echo ""
  echo "Running Prometheus Targets Tests..."
  test_prometheus_targets
  test_prometheus_scrape_cadvisor
  test_prometheus_scrape_node_exporter
  
  echo ""
  echo "Running Alertmanager Tests..."
  test_alertmanager_config
  test_alertmanager_receivers
}
