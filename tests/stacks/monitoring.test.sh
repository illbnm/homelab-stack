#!/usr/bin/env bash
# monitoring.test.sh — Monitoring Stack Tests (Prometheus, Grafana, Loki, Promtail, Alertmanager)
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-stacks/monitoring/docker-compose.yml}"

test_prometheus_running() { test_start "Prometheus running"; assert_container_running "prometheus"; test_end; }
test_prometheus_healthy() { test_start "Prometheus healthy"; assert_container_healthy "prometheus" 60; test_end; }
test_prometheus_http() { test_start "Prometheus /-/healthy"; assert_http_200 "http://localhost:9090/-/healthy" 15; test_end; }
test_grafana_running() { test_start "Grafana running"; assert_container_running "grafana"; test_end; }
test_grafana_healthy() { test_start "Grafana healthy"; assert_container_healthy "grafana" 60; test_end; }
test_grafana_health_api() { test_start "Grafana /api/health"; assert_http_200 "http://localhost:3000/api/health" 15; test_end; }
test_loki_running() { test_start "Loki running"; assert_container_running "loki"; test_end; }
test_promtail_running() { test_start "Promtail running"; assert_container_running "promtail"; test_end; }
test_alertmanager_running() { test_start "Alertmanager running"; assert_container_running "alertmanager"; test_end; }
test_prometheus_targets() { test_start "Prometheus targets"; assert_http_200 "http://localhost:9090/api/v1/targets" 10; test_end; }
test_compose_syntax() { test_start "Monitoring compose syntax valid"; assert_exit_code 0 docker compose -f "$COMPOSE_FILE" config --quiet; test_end; }
