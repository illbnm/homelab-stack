#!/usr/bin/env bash
# =============================================================================
# Monitoring Stack Tests
# =============================================================================

assert_container_running prometheus
assert_container_healthy prometheus 30
assert_container_running grafana
assert_container_healthy grafana 30
assert_container_running loki
assert_container_healthy loki 30
assert_container_running alertmanager
assert_container_running cadvisor
assert_container_running node-exporter
assert_container_running uptime-kuma
assert_container_healthy uptime-kuma 30

# HTTP endpoints
assert_http_200 "http://localhost:9090/-/healthy" 10
assert_http_200 "http://localhost:3000/api/health" 10
assert_http_200 "http://localhost:9093/-/healthy" 10

# Prometheus targets
test_start "Prometheus targets UP"
local_up=$(curl -sf "http://localhost:9090/api/v1/targets" 2>/dev/null | jq '[.data.activeTargets[] | select(.health == "up")] | length' 2>/dev/null || echo "0")
if [[ "$local_up" -gt 0 ]]; then
  test_pass
else
  test_fail "No Prometheus targets UP"
fi
