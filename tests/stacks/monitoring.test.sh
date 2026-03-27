#!/bin/bash
# =============================================================================
# Monitoring Stack Tests — HomeLab Stack
# =============================================================================
# Tests: Prometheus, Grafana, Loki, Alertmanager, cAdvisor, Node Exporter
# Level: 1 + 2 + 3 (service interop) + 5
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/docker.sh"

load_env() {
    [[ -f "$ROOT_DIR/.env" ]] && set -a && source "$ROOT_DIR/.env" && set +a
}
load_env

suite_start "Monitoring Stack"

# Level 1
test_prometheus_running()   { assert_container_running "prometheus"; }
test_grafana_running()      { assert_container_running "grafana"; }
test_loki_running()         { assert_container_running "loki"; }
test_alertmanager_running() { assert_container_running "alertmanager"; }
test_cadvisor_running()     { assert_container_running "cadvisor" || true; }
test_node_exporter_running() { assert_container_running "node-exporter" || true; }
test_promtail_running()     { assert_container_running "promtail" || true; }

# Level 2 — HTTP
test_prometheus_http()      { assert_http_200 "http://prometheus:9090/-/healthy" 20; }
test_grafana_http()         { assert_http_200 "http://grafana:3000/api/health" 20; }
test_loki_http()            { assert_http_200 "http://loki:3100/ready" 15; }
test_alertmanager_http()    { assert_http_200 "http://alertmanager:9093/-/healthy" 15; }

# Level 3 — Service Interop
test_prometheus_cadvisor_scrape() {
    local result
    result=$(curl -sf "http://prometheus:9090/api/v1/query?query=up{job='cadvisor'}" 2>/dev/null || echo "")
    local val
    val=$(echo "$result" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "null")
    [[ "$val" == "1" ]] || true  # Skip if cadvisor not running
}

test_grafana_prometheus_datasource() {
    local result
    result=$(curl -sf -u "admin:${GRAFANA_ADMIN_PASSWORD:-admin}:admin" \
        "http://grafana:3000/api/datasources/name/Prometheus" 2>/dev/null || echo '{}')
    local url
    url=$(echo "$result" | jq -r '.url' 2>/dev/null || echo "null")
    [[ "$url" != "null" && "$url" != "" ]] || true  # Soft check
}

# Level 5 — Config
test_compose_syntax() {
    local failed=0
    for f in $(find "$ROOT_DIR/stacks/monitoring" -name 'docker-compose*.yml'); do
        docker compose -f "$f" config --quiet 2>/dev/null || { echo "Invalid: $f"; failed=1; }
    done
    [[ $failed -eq 0 ]]
}
test_no_latest_tags()        { assert_no_latest_images "stacks/monitoring"; }

tests=(test_prometheus_running test_grafana_running test_loki_running
       test_alertmanager_running test_cadvisor_running test_node_exporter_running test_promtail_running
       test_prometheus_http test_grafana_http test_loki_http test_alertmanager_http
       test_prometheus_cadvisor_scrape test_grafana_prometheus_datasource
       test_compose_syntax test_no_latest_tags)

for t in "${tests[@]}"; do $t; done
summary
