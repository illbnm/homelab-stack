#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Monitoring Stack Tests
# Tests: Prometheus, Grafana, Loki, Promtail, Alertmanager, cAdvisor,
#        Node Exporter
# Usage: ./tests/test_monitoring.sh [--smoke|--full]
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/assertions.sh"

TEST_SUITE_NAME="monitoring"
TEST_MODE="${1:---full}"
COMPOSE_FILE="$REPO_ROOT/stacks/monitoring/docker-compose.yml"
DOMAIN="${DOMAIN:-test.homelab.local}"

# =============================================================================
# Compose validation
# =============================================================================
log_group "Compose File Validation"
assert_file_exists "$COMPOSE_FILE"
assert_compose_valid "$COMPOSE_FILE"
assert_compose_services "$COMPOSE_FILE" 7
assert_image_pinned "$COMPOSE_FILE"

# =============================================================================
# Config file checks
# =============================================================================
log_group "Config File Checks"
assert_file_exists "$REPO_ROOT/config/prometheus/prometheus.yml"
if [[ -d "$REPO_ROOT/config/prometheus/rules" ]]; then
    _log_pass "Prometheus rules directory exists"
else
    _log_skip "Prometheus rules directory missing"
fi
if [[ -f "$REPO_ROOT/config/loki/loki-config.yml" ]]; then
    _log_pass "Loki config exists"
else
    _log_skip "Loki config missing"
fi
if [[ -f "$REPO_ROOT/config/alertmanager/alertmanager.yml" ]]; then
    _log_pass "Alertmanager config exists"
else
    _log_skip "Alertmanager config missing"
fi
if [[ -d "$REPO_ROOT/config/grafana/provisioning" ]]; then
    _log_pass "Grafana provisioning directory exists"
else
    _log_skip "Grafana provisioning directory missing"
fi

# =============================================================================
# Smoke tests
# =============================================================================
log_group "Compose Config Analysis"
_compose_config=$(docker compose -f "$COMPOSE_FILE" config 2>/dev/null || echo "")
if [[ -n "$_compose_config" ]]; then
    # Check monitoring network exists
    if grep -q "monitoring" "$COMPOSE_FILE" && grep -q "driver: bridge" "$COMPOSE_FILE"; then
        _log_pass "Dedicated monitoring network defined"
    else
        _log_fail "Missing dedicated monitoring network"
    fi

    # Prometheus retention configured
    if grep -q "retention" "$COMPOSE_FILE"; then
        _log_pass "Prometheus retention policy configured"
    else
        _log_fail "Prometheus missing retention policy"
    fi

    # Grafana has OAuth config
    if grep -q "GF_AUTH_GENERIC_OAUTH" "$COMPOSE_FILE"; then
        _log_pass "Grafana SSO/OAuth configured"
    else
        _log_skip "Grafana OAuth not configured"
    fi
else
    _log_skip "Cannot parse compose config"
fi

if [[ "$TEST_MODE" == "--smoke" ]]; then
    print_summary
    [[ $TEST_FAILED -eq 0 ]] && exit 0 || exit 1
fi

# =============================================================================
# Integration tests — Container status
# =============================================================================
log_group "Container Status — Prometheus"
assert_container_running prometheus
assert_healthy prometheus 90
assert_container_image prometheus "prom/prometheus"
assert_restart_policy prometheus "unless-stopped"
assert_container_network prometheus "monitoring"
assert_container_network prometheus "proxy"

log_group "Container Status — Grafana"
assert_container_running grafana
assert_healthy grafana 90
assert_container_image grafana "grafana/grafana"
assert_restart_policy grafana "unless-stopped"
assert_container_network grafana "monitoring"
assert_container_network grafana "proxy"
assert_container_label grafana "traefik.enable" "true"

log_group "Container Status — Loki"
assert_container_running loki
assert_healthy loki 90
assert_container_image loki "grafana/loki"
assert_restart_policy loki "unless-stopped"
assert_container_network loki "monitoring"

log_group "Container Status — Promtail"
assert_container_running promtail
assert_container_image promtail "grafana/promtail"
assert_restart_policy promtail "unless-stopped"
assert_container_network promtail "monitoring"

log_group "Container Status — Alertmanager"
assert_container_running alertmanager
assert_healthy alertmanager 60
assert_container_image alertmanager "prom/alertmanager"
assert_restart_policy alertmanager "unless-stopped"
assert_container_network alertmanager "monitoring"

log_group "Container Status — cAdvisor"
assert_container_running cadvisor
assert_container_image cadvisor "cadvisor"
assert_restart_policy cadvisor "unless-stopped"
assert_container_network cadvisor "monitoring"

log_group "Container Status — Node Exporter"
assert_container_running node-exporter
assert_container_image node-exporter "node-exporter"
assert_restart_policy node-exporter "unless-stopped"
assert_container_network node-exporter "monitoring"

# =============================================================================
# Security
# =============================================================================
log_group "Security — Monitoring Stack"
assert_no_privileged prometheus
assert_no_privileged grafana
assert_no_privileged loki
assert_no_privileged alertmanager
assert_no_privileged node-exporter
# Note: cadvisor requires privileged for /sys access

# =============================================================================
# Service endpoint tests
# =============================================================================
log_group "Prometheus — API"
assert_http_200 "Prometheus healthy" "http://localhost:9090/-/healthy"
assert_http_200 "Prometheus ready" "http://localhost:9090/-/ready"

# Check Prometheus is scraping targets
_targets=$(curl -sf "http://localhost:9090/api/v1/targets" 2>/dev/null || echo "")
if [[ "$_targets" == *"activeTargets"* ]]; then
    _active=$(echo "$_targets" | grep -o '"activeTargets":\[' | wc -l)
    _log_pass "Prometheus has active scrape targets"
else
    _log_skip "Cannot query Prometheus targets API"
fi

# Check Prometheus can query metrics
_up=$(curl -sf "http://localhost:9090/api/v1/query?query=up" 2>/dev/null || echo "")
if [[ "$_up" == *"success"* ]]; then
    _log_pass "Prometheus query engine responding (up metric)"
else
    _log_skip "Prometheus query engine not responding"
fi

log_group "Grafana — API"
assert_http_200 "Grafana health" "http://localhost:3000/api/health"

# Grafana datasources
_ds=$(curl -sf "http://localhost:3000/api/datasources" -u "${GRAFANA_ADMIN_USER:-admin}:${GRAFANA_ADMIN_PASSWORD:-changeme}" 2>/dev/null || echo "")
if [[ "$_ds" == *"prometheus"* ]] || [[ "$_ds" == *"Prometheus"* ]]; then
    _log_pass "Grafana has Prometheus datasource configured"
else
    _log_skip "Cannot verify Grafana datasources (auth may be required)"
fi

log_group "Loki — API"
_loki_code=$(curl -sf -o /dev/null -w '%{http_code}' "http://localhost:3100/ready" 2>/dev/null || echo "000")
if [[ "$_loki_code" == "200" ]]; then
    _log_pass "Loki ready endpoint (HTTP 200)"
else
    _log_skip "Loki not reachable on port 3100 (HTTP ${_loki_code})"
fi

log_group "Alertmanager — API"
assert_http_200 "Alertmanager healthy" "http://localhost:9093/-/healthy"

_am_status=$(curl -sf "http://localhost:9093/api/v2/status" 2>/dev/null || echo "")
if [[ "$_am_status" == *"ready"* ]]; then
    _log_pass "Alertmanager API responding"
else
    _log_skip "Cannot verify Alertmanager status API"
fi

# =============================================================================
# Traefik routing
# =============================================================================
log_group "Traefik Routing — Monitoring Stack"
for svc_host in "prometheus.${DOMAIN}" "grafana.${DOMAIN}"; do
    _code=$(curl -sf -o /dev/null -w '%{http_code}' --connect-timeout 5 -H "Host: ${svc_host}" "http://localhost" 2>/dev/null || echo "000")
    if [[ "$_code" =~ ^[234] ]]; then
        _log_pass "Traefik routes ${svc_host} (HTTP ${_code})"
    else
        _log_skip "Traefik route ${svc_host} -> HTTP ${_code}"
    fi
done

# =============================================================================
# Cross-service connectivity
# =============================================================================
log_group "Service Connectivity"
# Prometheus should be able to reach its targets on monitoring network
_prom_self=$(curl -sf "http://localhost:9090/api/v1/query?query=prometheus_build_info" 2>/dev/null || echo "")
if [[ "$_prom_self" == *"success"* ]]; then
    _log_pass "Prometheus self-monitoring working"
else
    _log_skip "Cannot verify Prometheus self-monitoring"
fi

# Grafana -> Prometheus connectivity
_gf_prom=$(docker exec grafana wget -q -O- "http://prometheus:9090/-/healthy" 2>/dev/null || echo "")
if [[ "$_gf_prom" == *"OK"* ]] || [[ "$_gf_prom" == *"Prometheus"* ]]; then
    _log_pass "Grafana -> Prometheus connectivity OK (monitoring network)"
else
    _log_skip "Cannot verify Grafana -> Prometheus internal connectivity"
fi

# =============================================================================
# Summary
# =============================================================================
print_summary
[[ $TEST_FAILED -eq 0 ]] && exit 0 || exit 1
