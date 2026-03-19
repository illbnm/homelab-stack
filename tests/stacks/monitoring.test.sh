#!/usr/bin/env bash
# =============================================================================
# monitoring.test.sh — Monitoring stack tests (prometheus, grafana, loki, etc.)
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1: Container health
# ---------------------------------------------------------------------------
test_suite "Monitoring — Containers"

test_prometheus_running() {
  assert_container_running "prometheus"
  assert_container_healthy "prometheus"
}

test_grafana_running() {
  assert_container_running "grafana"
  assert_container_healthy "grafana"
}

test_loki_running() {
  assert_container_running "loki"
  assert_container_healthy "loki"
}

test_alertmanager_running() {
  assert_container_running "alertmanager"
  assert_container_healthy "alertmanager"
}

test_cadvisor_running() {
  assert_container_running "cadvisor"
}

test_node_exporter_running() {
  assert_container_running "node-exporter"
}

test_prometheus_running
test_grafana_running
test_loki_running
test_alertmanager_running
test_cadvisor_running
test_node_exporter_running

# ---------------------------------------------------------------------------
# Level 2: HTTP endpoints
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 2 ]]; then
  test_suite "Monitoring — HTTP Endpoints"

  test_prometheus_health() {
    assert_http_200 "http://localhost:9090/-/healthy" "Prometheus /-/healthy"
  }

  test_grafana_health() {
    assert_http_200 "http://localhost:3000/api/health" "Grafana /api/health"
  }

  test_loki_ready() {
    assert_http_200 "http://localhost:3100/ready" "Loki /ready"
  }

  test_alertmanager_health() {
    assert_http_200 "http://localhost:9093/-/healthy" "Alertmanager /-/healthy"
  }

  test_prometheus_health
  test_grafana_health
  test_loki_ready
  test_alertmanager_health
fi

# ---------------------------------------------------------------------------
# Level 3: Service interconnection
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 3 ]]; then
  test_suite "Monitoring — Interconnection"

  test_prometheus_scrape_cadvisor() {
    local result
    result=$(curl -sf --connect-timeout 5 --max-time 10 \
      "http://localhost:9090/api/v1/query?query=up%7Bjob%3D%27cadvisor%27%7D" 2>/dev/null || echo "")
    if [[ -n "$result" ]]; then
      assert_json_value "$result" ".data.result[0].value[1]" "1" \
        "Prometheus scrapes cAdvisor (up=1)"
    else
      test_fail "Prometheus scrapes cAdvisor" "empty response from Prometheus API"
    fi
  }

  test_prometheus_scrape_node_exporter() {
    local result
    result=$(curl -sf --connect-timeout 5 --max-time 10 \
      "http://localhost:9090/api/v1/query?query=up%7Bjob%3D%27node-exporter%27%7D" 2>/dev/null || echo "")
    if [[ -n "$result" ]]; then
      assert_json_value "$result" ".data.result[0].value[1]" "1" \
        "Prometheus scrapes node-exporter (up=1)"
    else
      test_fail "Prometheus scrapes node-exporter" "empty response from Prometheus API"
    fi
  }

  test_grafana_prometheus_datasource() {
    local result
    result=$(curl -sf --connect-timeout 5 --max-time 10 \
      -u "${GRAFANA_ADMIN_USER:-admin}:${GRAFANA_ADMIN_PASSWORD:-admin}" \
      "http://localhost:3000/api/datasources" 2>/dev/null || echo "[]")
    assert_contains "$result" "prometheus" \
      "Grafana has Prometheus datasource"
  }

  test_grafana_loki_datasource() {
    local result
    result=$(curl -sf --connect-timeout 5 --max-time 10 \
      -u "${GRAFANA_ADMIN_USER:-admin}:${GRAFANA_ADMIN_PASSWORD:-admin}" \
      "http://localhost:3000/api/datasources" 2>/dev/null || echo "[]")
    assert_contains "$result" "loki" \
      "Grafana has Loki datasource"
  }

  test_prometheus_config() {
    assert_file_exists "$BASE_DIR/config/prometheus/prometheus.yml" "Prometheus config exists"
  }

  test_prometheus_scrape_cadvisor
  test_prometheus_scrape_node_exporter
  test_grafana_prometheus_datasource
  test_grafana_loki_datasource
  test_prometheus_config
fi
