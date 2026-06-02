#!/usr/bin/env bash
# =============================================================================
# Monitoring Stack Tests
# =============================================================================

test_prometheus_running() {
  assert_container_running "prometheus"
}

test_prometheus_healthy() {
  assert_container_healthy "prometheus" 60
}

test_prometheus_http() {
  assert_http_200 "http://localhost:9090/-/healthy" 10
}

test_grafana_running() {
  assert_container_running "grafana"
}

test_grafana_healthy() {
  assert_container_healthy "grafana" 60
}

test_grafana_http() {
  assert_http_200 "http://localhost:3000/api/health" 10
}

test_loki_running() {
  assert_container_running "loki"
}

test_loki_http() {
  assert_http_200 "http://localhost:3100/ready" 10
}

test_alertmanager_running() {
  assert_container_running "alertmanager"
}

test_alertmanager_http() {
  assert_http_200 "http://localhost:9093/-/healthy" 10
}

run_test_with_timing "monitoring" test_prometheus_running "Prometheus running"
run_test_with_timing "monitoring" test_prometheus_healthy "Prometheus healthy"
run_test_with_timing "monitoring" test_prometheus_http "Prometheus HTTP 200"
run_test_with_timing "monitoring" test_grafana_running "Grafana running"
run_test_with_timing "monitoring" test_grafana_healthy "Grafana healthy"
run_test_with_timing "monitoring" test_grafana_http "Grafana HTTP 200"
run_test_with_timing "monitoring" test_loki_running "Loki running"
run_test_with_timing "monitoring" test_loki_http "Loki HTTP 200"
run_test_with_timing "monitoring" test_alertmanager_running "Alertmanager running"
run_test_with_timing "monitoring" test_alertmanager_http "Alertmanager HTTP 200"
