#!/usr/bin/env bash
# =============================================================================
# Monitoring Stack Tests — Prometheus + Grafana + Loki
# =============================================================================

# --- Level 1: Container Health ---

test_monitoring_prometheus_running() {
  assert_container_running "homelab-prometheus"
}

test_monitoring_grafana_running() {
  assert_container_running "homelab-grafana"
}

test_monitoring_loki_running() {
  assert_container_running "homelab-loki"
}

# --- Level 1: Configuration ---

test_monitoring_compose_syntax() {
  local output
  output=$(compose_config_valid "stacks/monitoring/docker-compose.yml" 2>&1)
  _LAST_EXIT_CODE=$?
  assert_exit_code 0 "monitoring compose syntax invalid: ${output}"
}

test_monitoring_no_latest_tags() {
  assert_no_latest_images "stacks/monitoring/"
}

# --- Level 2: HTTP Endpoints ---

test_monitoring_prometheus_healthy() {
  local ip
  ip=$(get_container_ip homelab-prometheus)
  assert_http_200 "http://${ip}:9090/-/healthy" 30
}

test_monitoring_grafana_health() {
  local ip
  ip=$(get_container_ip homelab-grafana)
  assert_http_response "http://${ip}:3000/api/health" '"database":"ok"' 30
}
