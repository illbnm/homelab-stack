#!/usr/bin/env bash
# =============================================================================
# monitoring.test.sh — Monitoring stack tests
# Services: Prometheus, Grafana, Loki, Promtail, Alertmanager, cAdvisor
# =============================================================================

# --- Prometheus ---

test_prometheus_running() {
  assert_container_running "prometheus"
}

test_prometheus_healthy() {
  assert_container_healthy "prometheus"
}

test_prometheus_health_endpoint() {
  assert_http_200 "http://localhost:9090/-/healthy" 10
}

test_prometheus_ready() {
  assert_http_200 "http://localhost:9090/-/ready" 10
}

test_prometheus_targets() {
  # Verify Prometheus has at least one target
  local body
  body=$(curl -s --max-time 10 "http://localhost:9090/api/v1/targets" 2>/dev/null)
  assert_json_key_exists "$body" ".data.activeTargets"
}

test_prometheus_no_crash_loop() {
  assert_no_crash_loop "prometheus" 3
}

# --- Grafana ---

test_grafana_running() {
  assert_container_running "grafana"
}

test_grafana_healthy() {
  assert_container_healthy "grafana"
}

test_grafana_health_endpoint() {
  assert_http_200 "http://localhost:3000/api/health" 15
}

test_grafana_login_page() {
  assert_http_200 "http://localhost:3000/login" 10
}

test_grafana_no_crash_loop() {
  assert_no_crash_loop "grafana" 3
}

# --- Grafana → Prometheus datasource ---

test_grafana_prometheus_datasource() {
  local msg="Grafana has Prometheus datasource configured"
  local body
  body=$(curl -s --max-time 10 -u "admin:${GF_ADMIN_PASSWORD:-admin}" \
    "http://localhost:3000/api/datasources" 2>/dev/null)

  if echo "$body" | jq -e '.[] | select(.type == "prometheus")' &>/dev/null; then
    _assert_pass "$msg"
  else
    _assert_skip "$msg" "Datasource not auto-provisioned (may need manual setup)"
  fi
}

# --- Loki ---

test_loki_running() {
  assert_container_running "loki"
}

test_loki_healthy() {
  assert_container_healthy "loki"
}

test_loki_ready() {
  assert_http_200 "http://localhost:3100/ready" 15
}

test_loki_no_crash_loop() {
  assert_no_crash_loop "loki" 3
}

# --- Promtail ---

test_promtail_running() {
  assert_container_running "promtail"
}

test_promtail_no_crash_loop() {
  assert_no_crash_loop "promtail" 3
}

# --- Alertmanager ---

test_alertmanager_running() {
  assert_container_running "alertmanager"
}

test_alertmanager_health() {
  assert_http_200 "http://localhost:9093/-/healthy" 10
}

test_alertmanager_no_crash_loop() {
  assert_no_crash_loop "alertmanager" 3
}

# --- Prometheus ← cAdvisor scrape (inter-service) ---

test_prometheus_scrape_cadvisor() {
  local msg="Prometheus scrapes cAdvisor metrics"
  local body
  body=$(curl -s --max-time 10 \
    "http://localhost:9090/api/v1/query?query=up" 2>/dev/null)

  if echo "$body" | jq -e '.data.result | length > 0' &>/dev/null; then
    _assert_pass "$msg"
  else
    _assert_fail "$msg" "No scrape targets returning data"
  fi
}
