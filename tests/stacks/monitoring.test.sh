#!/usr/bin/env bash
# Monitoring stack tests
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

echo "🧪 Monitoring Stack Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "  [Containers]"
assert_container_running "prometheus"
assert_container_healthy "prometheus"
assert_container_running "grafana"
assert_container_healthy "grafana"
assert_container_running "alertmanager"
assert_container_running "cadvisor"
assert_container_running "node-exporter"

echo "  [HTTP Endpoints]"
assert_http_200 "http://localhost:9090/-/healthy" "Prometheus /-/healthy"
assert_http_200 "http://localhost:3000/api/health" "Grafana /api/health"
assert_http_200 "http://localhost:9093/-/healthy" "Alertmanager /-/healthy"

echo "  [Service Connectivity]"
# Prometheus scraping cAdvisor
PROM_RESULT=$(curl -sf "http://localhost:9090/api/v1/query?query=up" 2>/dev/null || echo '{}')
assert_contains "$PROM_RESULT" "success" "Prometheus query API responds"

print_summary
exit $FAIL
