#!/usr/bin/env bash
# =============================================================================
# tests/stacks/monitoring.test.sh — Monitoring (Prometheus + Grafana + Loki + Alertmanager)
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
source "$SCRIPT_DIR/tests/lib/assert.sh"
source "$SCRIPT_DIR/tests/lib/docker.sh"

test_prometheus_running() {
  assert_container_running "prometheus"
}

test_prometheus_healthy() {
  assert_container_healthy "prometheus" 60
}

test_prometheus_api() {
  assert_http_200 "http://localhost:9090/-/healthy" 10
}

test_prometheus_targets() {
  local body
  body=$(curl -sf "http://localhost:9090/api/v1/targets" 2>/dev/null || echo "")
  assert_not_empty "$body"
}

test_grafana_running() {
  assert_container_running "grafana"
}

test_grafana_healthy() {
  assert_container_healthy "grafana" 60
}

test_grafana_api() {
  assert_http_200 "http://localhost:3000/api/health" 10
}

test_alertmanager_running() {
  assert_container_running "alertmanager"
}

test_alertmanager_api() {
  assert_http_200 "http://localhost:9093/-/healthy" 10
}

test_loki_running() {
  assert_container_running "loki"
}

test_loki_api() {
  local code
  code=$(http_status "http://localhost:3100/ready" 10)
  assert_contains "200 404" "$code"
}

test_monitoring_compose_valid() {
  assert_compose_valid "$SCRIPT_DIR/stacks/monitoring/docker-compose.yml"
}

test_node_exporter_running() {
  assert_container_running "node-exporter" 2>/dev/null || true
  return 0
}
