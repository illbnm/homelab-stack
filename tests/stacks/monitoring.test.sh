#!/usr/bin/env bash
# Monitoring Stack Tests — Prometheus, Grafana, Loki, Alertmanager
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

reset_counters
log_test_start "Monitoring Stack"

section "Prometheus"
assert_container_running "Prometheus container" "homelab-prometheus"
assert_http_2xx "Prometheus API" "http://localhost:9090/-/healthy" \
  || assert_http_2xx "Prometheus runtimeinfo" "http://localhost:9090/api/v1/status/runtimeinfo" \
  || true

section "Grafana"
assert_container_running "Grafana container" "homelab-grafana"
assert_http_2xx "Grafana health" "http://localhost:3001/api/health" || true

section "Loki"
assert_container_running "Loki container" "homelab-loki"
assert_http_2xx "Loki ready" "http://localhost:3100/ready" || true

section "Alertmanager"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^homelab-alertmanager$"; then
  assert_container_running "Alertmanager running" "homelab-alertmanager"
  assert_http_2xx "Alertmanager health" "http://localhost:9093/-/healthy" || true
else
  skip "Alertmanager not deployed"
fi

assert_summary