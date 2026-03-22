#!/usr/bin/env bash
# monitoring.test.sh — Tests for the monitoring stack

STACK_DIR="${REPO_ROOT}/stacks/monitoring"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"

PROMETHEUS_HOST="${PROMETHEUS_HOST:-localhost}"
GRAFANA_HOST="${GRAFANA_HOST:-localhost}"
LOKI_HOST="${LOKI_HOST:-localhost}"
ALERTMANAGER_HOST="${ALERTMANAGER_HOST:-localhost}"

# ── Level 1: Configuration Integrity ──────────────────────────────────────────

if docker compose -f "$COMPOSE_FILE" config --quiet 2>/dev/null; then
  assert_pass "monitoring: compose syntax valid"
else
  assert_fail "monitoring: compose syntax valid" "docker compose config failed"
fi

assert_no_latest_images "monitoring: no :latest image tags" "$COMPOSE_FILE"

# ── Level 1: Container Health ──────────────────────────────────────────────────

for container in prometheus grafana loki alertmanager cadvisor; do
  if docker_container_exists "$container"; then
    assert_container_running "monitoring: ${container} is running" "$container"
  else
    assert_skip "monitoring: ${container} is running" "container not deployed"
  fi
done

# ── Level 2: HTTP Endpoints ────────────────────────────────────────────────────

if docker_container_exists "prometheus"; then
  assert_http_200 "monitoring: Prometheus UI responds" \
    "http://${PROMETHEUS_HOST}:9090/-/healthy"
else
  assert_skip "monitoring: Prometheus UI responds" "container not deployed"
fi

if docker_container_exists "grafana"; then
  assert_http_200 "monitoring: Grafana UI responds" \
    "http://${GRAFANA_HOST}:3000/api/health"
else
  assert_skip "monitoring: Grafana UI responds" "container not deployed"
fi

if docker_container_exists "loki"; then
  assert_http_200 "monitoring: Loki ready" \
    "http://${LOKI_HOST}:3100/ready"
else
  assert_skip "monitoring: Loki ready" "container not deployed"
fi

if docker_container_exists "alertmanager"; then
  assert_http_200 "monitoring: Alertmanager ready" \
    "http://${ALERTMANAGER_HOST}:9093/-/healthy"
else
  assert_skip "monitoring: Alertmanager ready" "container not deployed"
fi

# ── Level 3: Inter-Service Connectivity ───────────────────────────────────────

if docker_container_exists "prometheus" && docker_container_exists "cadvisor"; then
  targets_json=$(curl -s --max-time 10 \
    "http://${PROMETHEUS_HOST}:9090/api/v1/targets" 2>/dev/null || echo '{}')
  if echo "$targets_json" | jq -e '.data.activeTargets[]? | select(.labels.job == "cadvisor") | select(.health == "up")' &>/dev/null; then
    assert_pass "monitoring: Prometheus scraping cAdvisor"
  else
    assert_fail "monitoring: Prometheus scraping cAdvisor" "cAdvisor target not up in Prometheus"
  fi
else
  assert_skip "monitoring: Prometheus scraping cAdvisor" "containers not deployed"
fi

if docker_container_exists "grafana"; then
  grafana_health=$(curl -s --max-time 10 \
    "http://${GRAFANA_HOST}:3000/api/health" 2>/dev/null || echo '{}')
  assert_json_value "monitoring: Grafana reports healthy" \
    "$grafana_health" '.database' "ok"
else
  assert_skip "monitoring: Grafana datasource healthy" "container not deployed"
fi
