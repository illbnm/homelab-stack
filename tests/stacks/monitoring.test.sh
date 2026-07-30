#!/usr/bin/env bash
# Monitoring Stack Tests — Prometheus + Grafana + Loki + Tempo + Alertmanager + Uptime Kuma
test_prometheus_running() { assert_eq "$(container_status prometheus)" "running" "Prometheus should be running"; }
test_prometheus_healthy() { assert_http_200 "http://localhost:9090/-/healthy" "Prometheus should be healthy"; }
test_prometheus_ready() { assert_http_200 "http://localhost:9090/-/ready" "Prometheus should be ready"; }
test_grafana_running() { assert_eq "$(container_status grafana)" "running" "Grafana should be running"; }
test_grafana_health() { assert_http_200 "http://localhost:3000/api/health" "Grafana health endpoint"; }
test_loki_running() { assert_eq "$(container_status loki)" "running" "Loki should be running"; }
test_loki_ready() { assert_http_200 "http://localhost:3100/ready" "Loki should be ready"; }
test_alertmanager_running() { assert_eq "$(container_status alertmanager)" "running" "Alertmanager should be running"; }
test_alertmanager_api() { assert_http_status "http://localhost:9093/-/healthy" "200" "Alertmanager should be healthy"; }
test_uptime_kuma_running() { assert_eq "$(container_status uptime-kuma)" "running" "Uptime Kuma should be running"; }

test_prometheus_scrape_cadvisor() {
  local result
  result=$(curl -s "http://localhost:9090/api/v1/query?query=up{job='cadvisor'}" 2>/dev/null || echo "{}")
  assert_json_value "$result" ".data.result[0].value[1]" "1" "Prometheus should scrape cAdvisor"
}
test_grafana_prometheus_datasource() {
  local result
  result=$(curl -s -u "admin:${GF_ADMIN_PASSWORD:-admin}" "http://localhost:3000/api/datasources/name/Prometheus" 2>/dev/null || echo "")
  assert_json_key_exists "$result" ".url" "Grafana should have Prometheus datasource"
}