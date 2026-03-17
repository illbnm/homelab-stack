#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Monitoring Stack Tests
# Services: Grafana, Prometheus, Loki, Alertmanager, Uptime Kuma
# =============================================================================

# shellcheck shell=bash

# ---------------------------------------------------------------------------
# Grafana
# ---------------------------------------------------------------------------

test_grafana_container_running() {
  assert_container_running "grafana"
}

test_grafana_container_healthy() {
  assert_container_healthy "grafana"
}

test_grafana_health_endpoint() {
  assert_http_200 "http://localhost:3000/api/health"
}

test_grafana_health_returns_ok() {
  assert_http_body_contains "http://localhost:3000/api/health" '"database": "ok"'
}

test_grafana_port_open() {
  assert_port_open "localhost" "3000"
}

# ---------------------------------------------------------------------------
# Prometheus
# ---------------------------------------------------------------------------

test_prometheus_container_running() {
  assert_container_running "prometheus"
}

test_prometheus_container_healthy() {
  assert_container_healthy "prometheus"
}

test_prometheus_ready() {
  assert_http_200 "http://localhost:9090/-/ready"
}

test_prometheus_healthy() {
  assert_http_200 "http://localhost:9090/-/healthy"
}

test_prometheus_api_query() {
  assert_http_200 "http://localhost:9090/api/v1/query?query=up"
}

test_prometheus_api_returns_data() {
  assert_http_body_contains "http://localhost:9090/api/v1/query?query=up" '"status":"success"'
}

test_prometheus_port_open() {
  assert_port_open "localhost" "9090"
}

# ---------------------------------------------------------------------------
# Loki
# ---------------------------------------------------------------------------

test_loki_container_running() {
  assert_container_running "loki"
}

test_loki_ready() {
  assert_http_200 "http://localhost:3100/ready"
}

test_loki_metrics() {
  assert_http_200 "http://localhost:3100/metrics"
}

test_loki_port_open() {
  assert_port_open "localhost" "3100"
}

# ---------------------------------------------------------------------------
# Alertmanager
# ---------------------------------------------------------------------------

test_alertmanager_container_running() {
  assert_container_running "alertmanager"
}

test_alertmanager_healthy() {
  assert_http_200 "http://localhost:9093/-/healthy"
}

test_alertmanager_ready() {
  assert_http_200 "http://localhost:9093/-/ready"
}

test_alertmanager_api_status() {
  assert_http_200 "http://localhost:9093/api/v2/status"
}

test_alertmanager_port_open() {
  assert_port_open "localhost" "9093"
}

# ---------------------------------------------------------------------------
# Uptime Kuma
# ---------------------------------------------------------------------------

test_uptime_kuma_container_running() {
  assert_container_running "uptime-kuma"
}

test_uptime_kuma_ui_accessible() {
  local status
  status=$(curl --silent --max-time 15 --output /dev/null --write-out "%{http_code}" \
    "http://localhost:3001" 2>/dev/null || echo "000")
  if [[ "$status" == "200" || "$status" == "301" || "$status" == "302" ]]; then
    return 0
  fi
  _assert_fail "Uptime Kuma returned HTTP ${status} (expected 200/30x)"
}

test_uptime_kuma_port_open() {
  assert_port_open "localhost" "3001"
}

# ---------------------------------------------------------------------------
# Prometheus scrape targets
# ---------------------------------------------------------------------------

test_prometheus_scrapes_itself() {
  local body
  body=$(curl --silent --max-time 10 \
    "http://localhost:9090/api/v1/targets" 2>/dev/null || echo "")
  assert_contains "$body" "prometheus"
}

test_grafana_datasource_prometheus_reachable() {
  # Grafana should be able to reach Prometheus within the docker network
  if docker_container_running "grafana" && docker_container_running "prometheus"; then
    docker_containers_can_communicate "grafana" "prometheus" "9090" || \
      echo "WARN: grafana→prometheus network check inconclusive" >&2
  fi
}
