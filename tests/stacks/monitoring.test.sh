#!/usr/bin/env bash
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib"; pwd)"
source "$_LIB_DIR/assert.sh"

test_monitoring_prometheus_running() { assert_container_running "prometheus" "Prometheus should be running"; }
test_monitoring_prometheus_health() { assert_http_200 "http://localhost:9090/-/healthy" 15 "Prometheus health endpoint"; }
test_monitoring_grafana_running() { assert_container_running "grafana" "Grafana should be running"; }
test_monitoring_grafana_health() { assert_http_200 "http://localhost:3000/api/health" 15 "Grafana health endpoint"; }
test_monitoring_loki_running() { assert_container_running "loki" "Loki should be running"; }
test_monitoring_alertmanager_running() { assert_container_running "alertmanager" "Alertmanager should be running"; }
test_monitoring_alertmanager_health() { assert_http_200 "http://localhost:9093/-/healthy" 15 "Alertmanager health endpoint"; }
test_monitoring_no_latest_tags() { assert_no_latest_images "$BASE_DIR/stacks/monitoring" "Monitoring stack should pin image versions"; }
