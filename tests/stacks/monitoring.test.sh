#!/usr/bin/env bash
# =============================================================================
# Monitoring Stack Tests — Prometheus, Grafana, Loki, Alertmanager, cAdvisor
# =============================================================================

log_group "Monitoring"

# --- Level 1: Container health ---

MONITORING_CONTAINERS=(prometheus grafana loki promtail alertmanager cadvisor node-exporter)

for c in "${MONITORING_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_running "$c"
    assert_container_healthy "$c"
    assert_container_not_restarting "$c"
  else
    skip_test "Container '$c'" "not running"
  fi
done

# --- Level 1: Network ---
test_monitoring_network() {
  assert_network_exists "monitoring"
  for c in prometheus grafana loki alertmanager; do
    if is_container_running "$c"; then
      assert_container_on_network "$c" "monitoring"
    fi
  done
  # Prometheus and Grafana must also be on proxy
  for c in prometheus grafana; do
    if is_container_running "$c"; then
      assert_container_on_network "$c" "proxy"
    fi
  done
}

test_monitoring_network

# --- Level 2: HTTP endpoints ---
if [[ "${TEST_LEVEL:-99}" -ge 2 ]]; then

  test_prometheus_http() {
    require_container "prometheus" || return
    assert_http_200 "http://localhost:9090/-/healthy" "Prometheus /-/healthy"
    assert_http_200 "http://localhost:9090/api/v1/status/config" "Prometheus API config"
  }

  test_grafana_http() {
    require_container "grafana" || return
    assert_http_200 "http://localhost:3000/api/health" "Grafana /api/health"
    # Check Grafana health response body
    assert_http_body_contains "http://localhost:3000/api/health" '"database": "ok"' \
      "Grafana health: database OK"
  }

  test_alertmanager_http() {
    require_container "alertmanager" || return
    assert_http_200 "http://localhost:9093/-/healthy" "Alertmanager /-/healthy"
  }

  test_loki_http() {
    require_container "loki" || return
    assert_http_200 "http://localhost:3100/ready" "Loki /ready"
  }

  test_prometheus_http
  test_grafana_http
  test_alertmanager_http
  test_loki_http
fi

# --- Level 3: Service interconnection ---
if [[ "${TEST_LEVEL:-99}" -ge 3 ]]; then

  # Prometheus must be able to scrape cAdvisor
  test_prometheus_scrape_cadvisor() {
    require_container "prometheus" || return
    local result
    result=$(curl -sf "http://localhost:9090/api/v1/query?query=up%7Bjob%3D%27cadvisor%27%7D" 2>/dev/null)
    if [[ -n "$result" ]]; then
      assert_json_value "$result" '.data.result[0].value[1]' "1" \
        "Prometheus scrapes cAdvisor (up=1)"
    else
      skip_test "Prometheus scrape cAdvisor" "query returned empty"
    fi
  }

  # Prometheus must be scraping node-exporter
  test_prometheus_scrape_node_exporter() {
    require_container "prometheus" || return
    local result
    result=$(curl -sf "http://localhost:9090/api/v1/query?query=up%7Bjob%3D%27node-exporter%27%7D" 2>/dev/null)
    if [[ -n "$result" ]]; then
      assert_json_value "$result" '.data.result[0].value[1]' "1" \
        "Prometheus scrapes node-exporter (up=1)"
    else
      skip_test "Prometheus scrape node-exporter" "query returned empty"
    fi
  }

  # Prometheus must scrape itself
  test_prometheus_scrape_self() {
    require_container "prometheus" || return
    local result
    result=$(curl -sf "http://localhost:9090/api/v1/query?query=up%7Bjob%3D%27prometheus%27%7D" 2>/dev/null)
    if [[ -n "$result" ]]; then
      assert_json_value "$result" '.data.result[0].value[1]' "1" \
        "Prometheus scrapes itself (up=1)"
    else
      skip_test "Prometheus scrape self" "query returned empty"
    fi
  }

  # Grafana must have Prometheus data source configured
  test_grafana_prometheus_datasource() {
    require_container "grafana" || return
    local result
    result=$(curl -sf -u "${GRAFANA_ADMIN_USER:-admin}:${GRAFANA_ADMIN_PASSWORD:-changeme}" \
      "http://localhost:3000/api/datasources/name/Prometheus" 2>/dev/null)
    if [[ -n "$result" ]]; then
      assert_json_key_exists "$result" ".url" \
        "Grafana has Prometheus datasource"
    else
      skip_test "Grafana Prometheus datasource" "API returned empty"
    fi
  }

  # Alertmanager receives alerts from Prometheus
  test_prometheus_alertmanager_config() {
    require_container "prometheus" || return
    local result
    result=$(curl -sf "http://localhost:9090/api/v1/status/config" 2>/dev/null)
    if [[ -n "$result" ]]; then
      local config
      config=$(echo "$result" | jq -r '.data.yaml' 2>/dev/null)
      assert_contains "$config" "alertmanager:9093" \
        "Prometheus config points to alertmanager:9093"
    else
      skip_test "Prometheus alertmanager config" "config API returned empty"
    fi
  }

  test_prometheus_scrape_cadvisor
  test_prometheus_scrape_node_exporter
  test_prometheus_scrape_self
  test_grafana_prometheus_datasource
  test_prometheus_alertmanager_config
fi

# --- Image tags ---
for c in "${MONITORING_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_image_not_latest "$c"
  fi
done
