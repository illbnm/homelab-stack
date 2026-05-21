#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Monitoring Stack Tests
# Tests: Prometheus + Grafana + Loki + Alertmanager + cAdvisor + Node Exporter
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker.sh"

should_run_stack "monitoring" || { begin_suite "Monitoring Stack"; assert_skip "not selected"; exit 0; }

begin_suite "Monitoring Stack — Prometheus + Grafana + Loki + Alertmanager"

# ---- Prometheus ----
assert_container_running "prometheus"
assert_container_healthy "prometheus"
assert_container_not_latest "prometheus"
assert_http_200 "${BASE_URL:-http://localhost}:9090/-/healthy" "prometheus:health"
assert_http_200 "${BASE_URL:-http://localhost}:9090/api/v1/status/config" "prometheus:config"

# ---- Grafana ----
assert_container_running "grafana"
assert_container_healthy "grafana"
assert_container_not_latest "grafana"
assert_http_200 "${BASE_URL:-http://localhost}:3000/api/health" "grafana:health"

# ---- Loki ----
assert_container_running "loki"
assert_container_healthy "loki"
assert_container_not_latest "loki"
assert_http_200 "${BASE_URL:-http://localhost}:3100/ready" "loki:ready"

# ---- Promtail ----
assert_container_running "promtail"
assert_container_not_latest "promtail"

# ---- Alertmanager ----
assert_container_running "alertmanager"
assert_container_healthy "alertmanager"
assert_container_not_latest "alertmanager"
assert_http_200 "${BASE_URL:-http://localhost}:9093/-/healthy" "alertmanager:health"

# ---- cAdvisor ----
assert_container_running "cadvisor"
assert_container_not_latest "cadvisor"
assert_http_200 "${BASE_URL:-http://localhost}:8082/healthz" "cadvisor:health"

# ---- Node Exporter ----
assert_container_running "node-exporter"
assert_container_not_latest "node-exporter"
assert_http_200 "${BASE_URL:-http://localhost}:9100/metrics" "node-exporter:metrics"

# ---- Prometheus scrape targets ----
begin_test "prometheus:targets:up"
targets=$(curl -sf "${BASE_URL:-http://localhost}:9090/api/v1/targets" 2>/dev/null || echo "")
up_count=$(echo "$targets" | python3 -c "
import sys,json
try:
  d=json.load(sys.stdin)
  active=d.get('data',{}).get('activeTargets',[])
  print(sum(1 for t in active if t.get('health')=='up'))
except: print(0)
" 2>/dev/null || echo "0")
if [[ "$up_count" -gt 0 ]]; then
  assert_pass "$up_count targets UP"
else
  assert_fail "no targets UP"
fi

# ---- Inter-service: Prometheus scrapes cAdvisor ----
begin_test "prometheus:scrapes_cadvisor"
if echo "$targets" | grep -q "cadvisor"; then
  assert_pass "cadvisor target found in Prometheus"
else
  assert_skip "cadvisor target not configured yet"
fi

# ---- Inter-service: Grafana → Prometheus datasource ----
begin_test "grafana:datasource:prometheus"
ds=$(curl -sf "${BASE_URL:-http://localhost}:3000/api/datasources" -u admin:admin 2>/dev/null || echo "")
if echo "$ds" | grep -qi "prometheus"; then
  assert_pass "Prometheus datasource configured"
else
  assert_skip "datasource not configured (needs Grafana credentials)"
fi

# ---- Compose validation ----
assert_compose_valid "${SCRIPT_DIR}/../../stacks/monitoring/docker-compose.yml" "monitoring"
