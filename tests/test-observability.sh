#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Observability Test Script
# Verifies complete observability stack functionality
#
# Usage: ./tests/test-observability.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# Load environment
if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo; echo -e "${BOLD}${CYAN}==> $*${RESET}"; }

DOMAIN="${DOMAIN:-yourdomain.com}"
PASSED=0
FAILED=0

test_http_endpoint() {
  local name="$1"
  local url="$2"
  
  if curl -sf -o /dev/null "$url"; then
    log_info "✅ $name: OK"
    PASSED=$((PASSED + 1))
  else
    log_error "❌ $name: FAILED"
    FAILED=$((FAILED + 1))
  fi
}

test_container_health() {
  local name="$1"
  
  if docker ps --filter "name=$name" --format "{{.Status}}" | grep -q "healthy"; then
    log_info "✅ $name: healthy"
    PASSED=$((PASSED + 1))
  else
    log_error "❌ $name: not healthy"
    FAILED=$((FAILED + 1))
  fi
}

test_prometheus_target() {
  local job="$1"
  local url="http://localhost:9090/api/v1/targets"
  
  local status
  status=$(curl -sf "$url" | jq -r ".data.activeTargets[] | select(.labels.job==\"$job\") | .health")
  
  if [ "$status" = "up" ]; then
    log_info "✅ Prometheus target $job: UP"
    PASSED=$((PASSED + 1))
  else
    log_error "❌ Prometheus target $job: $status"
    FAILED=$((FAILED + 1))
  fi
}

test_loki_logs() {
  local query='query={container="prometheus"}'
  local url="http://localhost:3100/loki/api/v1/query_range?$query&limit=1"
  
  if curl -sf "$url" | jq -e '.data.result | length > 0' > /dev/null; then
    log_info "✅ Loki log collection: OK"
    PASSED=$((PASSED + 1))
  else
    log_error "❌ Loki log collection: NO LOGS"
    FAILED=$((FAILED + 1))
  fi
}

test_alertmanager_config() {
  local url="http://localhost:9093/api/v2/status"
  
  if curl -sf "$url" > /dev/null; then
    log_info "✅ Alertmanager: configured"
    PASSED=$((PASSED + 1))
  else
    log_error "❌ Alertmanager: not responding"
    FAILED=$((FAILED + 1))
  fi
}

log_step "Testing container health..."

test_container_health "prometheus"
test_container_health "grafana"
test_container_health "loki"
test_container_health "promtail"
test_container_health "alertmanager"
test_container_health "cadvisor"
test_container_health "node-exporter"
test_container_health "tempo"
test_container_health "uptime-kuma"

log_step "Testing Prometheus targets..."

test_prometheus_target "prometheus"
test_prometheus_target "node-exporter"
test_prometheus_target "cadvisor"
test_prometheus_target "traefik"
test_prometheus_target "loki"
test_prometheus_target "alertmanager"

log_step "Testing Grafana dashboards..."

test_http_endpoint "Grafana Web UI" "https://grafana.${DOMAIN}/"
test_http_endpoint "Grafana Health" "https://grafana.${DOMAIN}/api/health"

log_step "Testing Loki logs..."

test_loki_logs

log_step "Testing Alertmanager..."

test_alertmanager_config

log_step "Testing Uptime Kuma..."

test_http_endpoint "Uptime Kuma Status Page" "https://status.${DOMAIN}/"
test_http_endpoint "Uptime Kuma Health" "https://status.${DOMAIN}/health"

log_step "Testing Tempo traces..."

test_http_endpoint "Tempo Ready" "http://localhost:3200/ready"

log_step "Test results..."

echo
log_info "Tests passed: $PASSED"
if [ $FAILED -gt 0 ]; then
  log_error "Tests failed: $FAILED"
  log_error ""
  log_error "Please check the failed services:"
  log_error "  - Container logs: docker logs <container-name>"
  log_error "  - Prometheus targets: https://prometheus.${DOMAIN}/targets"
  log_error "  - Grafana dashboards: https://grafana.${DOMAIN}"
  exit 1
else
  log_info "All tests passed! ✅"
fi

exit 0
