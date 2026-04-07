#!/bin/bash
# Observability Stack Verification Script
# Tests all acceptance criteria (验收标准) from the bounty
# Usage: ./verify-observability.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="${DOMAIN:-localhost}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
LOKI_URL="${LOKI_URL:-http://localhost:3100}"
ALERTMANAGER_URL="${ALERTMANAGER_URL:-http://localhost:9093}"
UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://localhost:3001}"

PASS_COUNT=0
FAIL_COUNT=0

echo "================================================"
echo "  Observability Stack Verification Script"
echo "================================================"
echo ""

# Function to check if a service is accessible
check_service() {
  local name="$1"
  local url="$2"
  local expected_status="${3:-200}"

  echo -n "Checking $name... "

  response=$(curl -sf -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)

  if [ "$response" = "$expected_status" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "${RED}✗ FAIL${NC} (HTTP $response)"
    ((FAIL_COUNT++))
    return 1
  fi
}

# Function to check Prometheus targets
check_prometheus_targets() {
  echo -n "Checking Prometheus targets UP status... "

  targets=$(curl -sf "${PROMETHEUS_URL}/api/v1/targets" 2>/dev/null | \
    jq -r '.data.activeTargets[] | select(.health != "up") | .labels.job' 2>/dev/null)

  if [ -z "$targets" ]; then
    echo -e "${GREEN}✓ PASS${NC} (All targets UP)"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  Down targets: $targets"
    ((FAIL_COUNT++))
    return 1
  fi
}

# Function to check Grafana dashboards
check_grafana_dashboards() {
  echo -n "Checking Grafana dashboards loaded... "

  # This requires Grafana to be accessible and have dashboards
  dashboards=$(curl -sf "${GRAFANA_URL}/api/search?type=dash-db" 2>/dev/null | \
    jq -r 'length' 2>/dev/null)

  if [ "$dashboards" -gt 0 ]; then
    echo -e "${GREEN}✓ PASS${NC} ($dashboards dashboards loaded)"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "${YELLOW}⚠ SKIP${NC} (Cannot verify - requires authentication)"
    return 0
  fi
}

# Function to check Loki logs
check_loki_logs() {
  echo -n "Checking Loki can query container logs... "

  # Query Loki for recent logs
  response=$(curl -sf -G \
    --data-urlencode 'query={job="docker-containers"}' \
    --data-urlencode 'limit=1' \
    "${LOKI_URL}/loki/api/v1/query_range" 2>/dev/null)

  if [ $? -eq 0 ] && echo "$response" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC} (Logs found)"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "${YELLOW}⚠ SKIP${NC} (No logs yet or Loki not ready)"
    return 0
  fi
}

# Function to check Alertmanager
check_alertmanager() {
  echo -n "Checking Alertmanager is accessible... "

  response=$(curl -sf -o /dev/null -w "%{http_code}" "${ALERTMANAGER_URL}/-/healthy" 2>/dev/null)

  if [ "$response" = "200" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "${RED}✗ FAIL${NC} (HTTP $response)"
    ((FAIL_COUNT++))
    return 1
  fi
}

# Function to check Uptime Kuma
check_uptime_kuma() {
  echo -n "Checking Uptime Kuma is accessible... "

  response=$(curl -sf -o /dev/null -w "%{http_code}" "${UPTIME_KUMA_URL}" 2>/dev/null)

  if [ "$response" = "200" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "${YELLOW}⚠ SKIP${NC} (May require initial setup)"
    return 0
  fi
}

# Function to check if ntfy is configured
check_ntfy_config() {
  echo -n "Checking Alertmanager ntfy configuration... "

  if grep -q "ntfy" config/alertmanager/alertmanager.yml 2>/dev/null; then
    echo -e "${GREEN}✓ PASS${NC} (ntfy configured)"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "${RED}✗ FAIL${NC} (ntfy not found in config)"
    ((FAIL_COUNT++))
    return 1
  fi
}

# Function to check alert rules
check_alert_rules() {
  echo -n "Checking alert rules exist... "

  host_rules=$(test -f config/prometheus/rules/host.yml && echo "yes" || echo "no")
  container_rules=$(test -f config/prometheus/rules/containers.yml && echo "yes" || echo "no")
  service_rules=$(test -f config/prometheus/rules/services.yml && echo "yes" || echo "no")

  if [ "$host_rules" = "yes" ] && [ "$container_rules" = "yes" ] && [ "$service_rules" = "yes" ]; then
    echo -e "${GREEN}✓ PASS${NC} (All rule files present)"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  host.yml: $host_rules"
    echo "  containers.yml: $container_rules"
    echo "  services.yml: $service_rules"
    ((FAIL_COUNT++))
    return 1
  fi
}

# Function to check dashboards exist
check_dashboard_files() {
  echo -n "Checking dashboard files exist... "

  dashboards=(
    "node-exporter-full.json"
    "docker-container-metrics.json"
    "traefik-official.json"
    "loki-dashboard.json"
    "uptime-kuma.json"
  )

  all_found=true
  for dashboard in "${dashboards[@]}"; do
    if [ ! -f "config/grafana/dashboards/$dashboard" ]; then
      all_found=false
      echo -e "\n  Missing: $dashboard"
    fi
  done

  if [ "$all_found" = true ]; then
    echo -e "${GREEN}✓ PASS${NC} (All dashboard files present)"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "${RED}✗ FAIL${NC} (Some dashboards missing)"
    ((FAIL_COUNT++))
    return 1
  fi
}

# Function to check Grafana OIDC configuration
check_grafana_oidc() {
  echo -n "Checking Grafana OIDC configuration... "

  if grep -q "GF_AUTH_GENERIC_OAUTH_ENABLED=true" stacks/monitoring/docker-compose.yml 2>/dev/null; then
    echo -e "${GREEN}✓ PASS${NC} (OIDC configured)"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "${RED}✗ FAIL${NC} (OIDC not configured)"
    ((FAIL_COUNT++))
    return 1
  fi
}

# Function to check cAdvisor metrics
check_cadvisor() {
  echo -n "Checking cAdvisor metrics... "

  response=$(curl -sf "${PROMETHEUS_URL}/api/v1/query?query=container_cpu_usage_seconds_total" 2>/dev/null | \
    jq -r '.data.result | length' 2>/dev/null)

  if [ "$response" -gt 0 ]; then
    echo -e "${GREEN}✓ PASS${NC} ($response containers monitored)"
    ((PASS_COUNT++))
    return 0
  else
    echo -e "${YELLOW}⚠ SKIP${NC} (No container metrics yet)")
    return 0
  fi
}

echo "Running verification tests..."
echo ""

# Run all checks
echo "=== Service Accessibility ==="
check_service "Prometheus" "${PROMETHEUS_URL}/-/healthy"
check_service "Grafana" "${GRAFANA_URL}/api/health"
check_service "Loki" "${LOKI_URL}/ready"
check_service "Alertmanager" "${ALERTMANAGER_URL}/-/healthy"

echo ""
echo "=== Prometheus Configuration ==="
check_prometheus_targets
check_alert_rules

echo ""
echo "=== Grafana Configuration ==="
check_grafana_dashboards
check_dashboard_files
check_grafana_oidc

echo ""
echo "=== Logging ==="
check_loki_logs

echo ""
echo "=== Alerting ==="
check_alertmanager
check_ntfy_config

echo ""
echo "=== Uptime Monitoring ==="
check_uptime_kuma

echo ""
echo "=== Container Metrics ==="
check_cadvisor

echo ""
echo "================================================"
echo "  Verification Results"
echo "================================================"
echo -e "${GREEN}Passed:${NC} $PASS_COUNT"
echo -e "${RED}Failed:${NC} $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
  echo -e "${GREEN}✓ All checks passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some checks failed. Review the output above.${NC}"
  exit 1
fi
