test_prometheus_running() {
  assert_container_running "prometheus"
  assert_container_healthy "prometheus"
}

test_grafana_running() {
  assert_container_running "grafana"
  assert_container_healthy "grafana"
}

test_loki_running() {
  assert_container_running "loki"
  assert_container_healthy "loki"
}

test_promtail_running() {
  assert_container_running "promtail"
}

test_alertmanager_running() {
  assert_container_running "alertmanager"
  assert_container_healthy "alertmanager"
}

test_cadvisor_running() {
  assert_container_running "cadvisor"
}

test_node_exporter_running() {
  assert_container_running "node-exporter"
}

