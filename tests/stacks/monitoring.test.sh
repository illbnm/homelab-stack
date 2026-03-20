#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Monitoring Tests
# Services: Prometheus, Grafana, Loki, Promtail, Alertmanager, cAdvisor, Node Exporter
# =============================================================================

COMPOSE_FILE="$BASE_DIR/stacks/monitoring/docker-compose.yml"

# ===========================================================================
# Level 1 — Configuration Integrity
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "Monitoring — Configuration"

  assert_compose_valid "$COMPOSE_FILE"

  assert_file_exists "$BASE_DIR/config/prometheus/prometheus.yml" \
    "Prometheus config exists"
  assert_file_exists "$BASE_DIR/config/loki/loki-config.yml" \
    "Loki config exists"
  assert_file_exists "$BASE_DIR/config/loki/promtail-config.yml" \
    "Promtail config exists"
  assert_file_exists "$BASE_DIR/config/alertmanager/alertmanager.yml" \
    "Alertmanager config exists"
fi

# ===========================================================================
# Level 1 — Container Health
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "Monitoring — Container Health"

  assert_container_running "prometheus"
  assert_container_healthy "prometheus"
  assert_container_not_restarting "prometheus"

  assert_container_running "grafana"
  assert_container_healthy "grafana"
  assert_container_not_restarting "grafana"

  assert_container_running "loki"
  assert_container_healthy "loki"
  assert_container_not_restarting "loki"

  assert_container_running "promtail"
  assert_container_not_restarting "promtail"

  assert_container_running "alertmanager"
  assert_container_healthy "alertmanager"
  assert_container_not_restarting "alertmanager"

  assert_container_running "cadvisor"
  assert_container_not_restarting "cadvisor"

  assert_container_running "node-exporter"
  assert_container_not_restarting "node-exporter"
fi

# ===========================================================================
# Level 2 — HTTP Endpoints
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 2 ]]; then
  test_group "Monitoring — HTTP Endpoints"

  assert_http_200 "http://localhost:9090/-/healthy" \
    "Prometheus /-/healthy"

  assert_http_200 "http://localhost:3000/api/health" \
    "Grafana /api/health"

  assert_http_200 "http://localhost:9093/-/healthy" \
    "Alertmanager /-/healthy"
fi

# ===========================================================================
# Level 3 — Service Interconnection
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 3 ]]; then
  test_group "Monitoring — Interconnection"

  assert_docker_network_exists "monitoring"

  # Prometheus can scrape itself
  if is_container_running "prometheus"; then
    prom_self=$(curl -sf "http://localhost:9090/api/v1/query?query=up{job='prometheus'}" 2>/dev/null)
    assert_json_value "$prom_self" ".data.result[0].value[1]" "1" \
      "Prometheus self-scrape is up"
  else
    skip_test "Prometheus self-scrape is up" "prometheus not running"
  fi

  # Prometheus scrapes cAdvisor
  if is_container_running "prometheus" && is_container_running "cadvisor"; then
    cadvisor_up=$(curl -sf "http://localhost:9090/api/v1/query?query=up{job='cadvisor'}" 2>/dev/null)
    assert_json_value "$cadvisor_up" ".data.result[0].value[1]" "1" \
      "Prometheus → cAdvisor scrape is up"
  else
    skip_test "Prometheus → cAdvisor scrape is up" "prometheus or cadvisor not running"
  fi

  # Prometheus scrapes node-exporter
  if is_container_running "prometheus" && is_container_running "node-exporter"; then
    node_up=$(curl -sf "http://localhost:9090/api/v1/query?query=up{job='node-exporter'}" 2>/dev/null)
    assert_json_value "$node_up" ".data.result[0].value[1]" "1" \
      "Prometheus → Node Exporter scrape is up"
  else
    skip_test "Prometheus → Node Exporter scrape is up" "prometheus or node-exporter not running"
  fi

  # Grafana has Prometheus datasource configured
  if is_container_running "grafana"; then
    gf_user="${GRAFANA_ADMIN_USER:-admin}"
    gf_pass="${GRAFANA_ADMIN_PASSWORD:-changeme}"
    local_ds_result=$(curl -sf -u "${gf_user}:${gf_pass}" \
      "http://localhost:3000/api/datasources" 2>/dev/null)
    if [[ -n "$local_ds_result" ]] && echo "$local_ds_result" | grep -q "prometheus\|Prometheus"; then
      _record_pass "Grafana has Prometheus datasource"
    else
      _record_fail "Grafana has Prometheus datasource" "datasource not found"
    fi
  else
    skip_test "Grafana has Prometheus datasource" "grafana not running"
  fi
fi
