#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Monitoring Stack Tests
# =============================================================================
# Tests: Grafana, Prometheus, Loki, Alertmanager, Uptime Kuma, cAdvisor,
#        Node Exporter, Promtail
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1 — Container Health
# ---------------------------------------------------------------------------

test_grafana_running() {
  assert_container_running "grafana"
}

test_grafana_healthy() {
  assert_container_healthy "grafana" 90
}

test_prometheus_running() {
  assert_container_running "prometheus"
}

test_prometheus_healthy() {
  assert_container_healthy "prometheus" 60
}

test_loki_running() {
  assert_container_running "loki"
}

test_loki_healthy() {
  assert_container_healthy "loki" 60
}

test_alertmanager_running() {
  assert_container_running "alertmanager"
}

test_alertmanager_healthy() {
  assert_container_healthy "alertmanager" 60
}

test_uptime_kuma_running() {
  assert_container_running "uptime-kuma"
}

test_uptime_kuma_healthy() {
  assert_container_healthy "uptime-kuma" 60
}

test_cadvisor_running() {
  assert_container_running "cadvisor"
}

test_node_exporter_running() {
  assert_container_running "node-exporter"
}

# ---------------------------------------------------------------------------
# Level 2 — HTTP Endpoints
# ---------------------------------------------------------------------------

test_grafana_api_health() {
  assert_http_200 "http://localhost:3000/api/health" 30
}

test_prometheus_healthy_endpoint() {
  assert_http_200 "http://localhost:9090/-/healthy" 30
}

test_prometheus_ready_endpoint() {
  assert_http_200 "http://localhost:9090/-/ready" 30
}

test_alertmanager_healthy_endpoint() {
  assert_http_200 "http://localhost:9093/-/healthy" 30
}

test_loki_ready_endpoint() {
  assert_http_200 "http://localhost:3100/ready" 30
}

test_uptime_kuma_webui() {
  assert_http_200 "http://localhost:3001" 30
}

test_cadvisor_metrics() {
  assert_http_200 "http://localhost:8082/metrics" 30
}

test_node_exporter_metrics() {
  assert_http_200 "http://localhost:9100/metrics" 30
}

# ---------------------------------------------------------------------------
# Level 3 — Inter-Service Communication
# ---------------------------------------------------------------------------

test_prometheus_scrape_cadvisor() {
  local result
  result=$(curl -s "http://localhost:9090/api/v1/query?query=up{job='cadvisor'}" 2>/dev/null || echo '{}')

  if echo "${result}" | jq -e '.data.result[0].value[1]' &>/dev/null; then
    local val
    val=$(echo "${result}" | jq -r '.data.result[0].value[1]')
    assert_eq "${val}" "1" "Prometheus should scrape cAdvisor (up=1)"
  else
    _assert_fail "Prometheus cannot query cAdvisor target"
  fi
}

test_prometheus_scrape_node_exporter() {
  local result
  result=$(curl -s "http://localhost:9090/api/v1/query?query=up{job='node-exporter'}" 2>/dev/null || echo '{}')

  if echo "${result}" | jq -e '.data.result[0].value[1]' &>/dev/null; then
    local val
    val=$(echo "${result}" | jq -r '.data.result[0].value[1]')
    assert_eq "${val}" "1" "Prometheus should scrape Node Exporter (up=1)"
  else
    _assert_fail "Prometheus cannot query Node Exporter target"
  fi
}

test_grafana_prometheus_datasource() {
  local gf_pass="${GF_ADMIN_PASSWORD:-admin}"
  local result
  result=$(curl -s -u "admin:${gf_pass}" \
    "http://localhost:3000/api/datasources/name/Prometheus" 2>/dev/null || echo '{}')

  assert_json_key_exists "${result}" ".url"
}

test_grafana_loki_datasource() {
  local gf_pass="${GF_ADMIN_PASSWORD:-admin}"
  local result
  result=$(curl -s -u "admin:${gf_pass}" \
    "http://localhost:3000/api/datasources/name/Loki" 2>/dev/null || echo '{}')

  assert_json_key_exists "${result}" ".url"
}

# ---------------------------------------------------------------------------
# Level 1 — Configuration
# ---------------------------------------------------------------------------

test_monitoring_compose_valid() {
  local compose_file="${PROJECT_ROOT}/stacks/monitoring/docker-compose.yml"

  if [[ ! -f "${compose_file}" ]]; then
    _assert_skip "Monitoring compose file not found"
    return 0
  fi

  assert_compose_valid "${compose_file}"
}

test_prometheus_config_exists() {
  local config="${PROJECT_ROOT}/config/prometheus/prometheus.yml"

  if [[ -f "${config}" ]]; then
    _assert_pass "Prometheus config exists"
  else
    _assert_skip "Prometheus config not found"
  fi
}

test_alertmanager_config_exists() {
  local config="${PROJECT_ROOT}/config/alertmanager/alertmanager.yml"

  if [[ -f "${config}" ]]; then
    _assert_pass "Alertmanager config exists"
  else
    _assert_skip "Alertmanager config not found"
  fi
}
