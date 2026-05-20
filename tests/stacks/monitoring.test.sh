#!/usr/bin/env bash

run_monitoring_tests() {
  CURRENT_SUITE="monitoring"
  assert_stack_static_checks monitoring
  assert_compose_services_declared monitoring prometheus grafana loki promtail alertmanager cadvisor node-exporter
  assert_stack_containers_running prometheus grafana loki promtail alertmanager cadvisor node-exporter
  assert_stack_containers_healthy prometheus grafana loki alertmanager
  assert_file_contains "$PROJECT_ROOT/config/prometheus/prometheus.yml" 'scrape_configs:' "Prometheus scrape configuration exists"
  assert_container_on_network grafana proxy "Grafana is attached to proxy network"
}
