#!/bin/bash
# =============================================================================
# Observability Stack Verification Script
# Verifies all components are properly configured and running
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
WARN=0

# Helper functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_test() {
    echo -ne "Testing $1... "
}

pass() {
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASS++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}"
    echo -e "${RED}  → $1${NC}"
    ((FAIL++))
}

warn() {
    echo -e "${YELLOW}⚠ WARN${NC}"
    echo -e "${YELLOW}  → $1${NC}"
    ((WARN++))
}

# =============================================================================
# Main Verification
# =============================================================================

print_header "Observability Stack Verification"

# Check if running in correct directory
if [ ! -f "docker-compose.yml" ] || [ ! -d "../../config/prometheus" ]; then
    echo -e "${RED}Error: Please run this script from the monitoring stack directory${NC}"
    echo -e "${RED}Usage: cd stacks/monitoring && ../../scripts/verify-observability.sh${NC}"
    exit 1
fi

# =============================================================================
# 1. Docker Services
# =============================================================================

print_header "1. Docker Services"

SERVICES=(
    "prometheus"
    "grafana"
    "loki"
    "promtail"
    "tempo"
    "alertmanager"
    "cadvisor"
    "node-exporter"
    "uptime-kuma"
)

for service in "${SERVICES[@]}"; do
    print_test "$service container"
    if docker compose ps "$service" 2>/dev/null | grep -q "Up"; then
        pass
    else
        fail "Container not running"
    fi
done

# Optional: Grafana OnCall
print_test "grafana-oncall (optional)"
if docker compose ps grafana-oncall 2>/dev/null | grep -q "Up"; then
    pass
else
    warn "Optional service not running"
fi

# =============================================================================
# 2. Service Health Checks
# =============================================================================

print_header "2. Service Health Checks"

# Prometheus
print_test "Prometheus health"
if curl -sf http://localhost:9090/-/healthy > /dev/null 2>&1; then
    pass
else
    fail "Prometheus not healthy"
fi

# Grafana
print_test "Grafana health"
if curl -sf http://localhost:3000/api/health > /dev/null 2>&1; then
    pass
else
    fail "Grafana not healthy"
fi

# Loki
print_test "Loki ready"
if curl -sf http://localhost:3100/ready > /dev/null 2>&1; then
    pass
else
    fail "Loki not ready"
fi

# Tempo
print_test "Tempo ready"
if curl -sf http://localhost:3200/ready > /dev/null 2>&1; then
    pass
else
    fail "Tempo not ready"
fi

# Alertmanager
print_test "Alertmanager health"
if curl -sf http://localhost:9093/-/healthy > /dev/null 2>&1; then
    pass
else
    fail "Alertmanager not healthy"
fi

# Uptime Kuma
print_test "Uptime Kuma"
if curl -sf http://localhost:3001 > /dev/null 2>&1; then
    pass
else
    fail "Uptime Kuma not responding"
fi

# =============================================================================
# 3. Prometheus Targets
# =============================================================================

print_header "3. Prometheus Targets"

REQUIRED_TARGETS=(
    "prometheus"
    "node-exporter"
    "cadvisor"
    "traefik"
    "loki"
    "tempo"
    "uptime-kuma"
    "grafana"
    "alertmanager"
)

for target in "${REQUIRED_TARGETS[@]}"; do
    print_test "$target target"
    if curl -sf http://localhost:9090/api/v1/targets 2>/dev/null | \
       jq -e ".data.activeTargets[] | select(.labels.job == \"$target\") | select(.health == \"up\")" > /dev/null 2>&1; then
        pass
    else
        fail "Target not up"
    fi
done

# Optional targets
OPTIONAL_TARGETS=("authentik" "nextcloud" "gitea")
for target in "${OPTIONAL_TARGETS[@]}"; do
    print_test "$target target (optional)"
    if curl -sf http://localhost:9090/api/v1/targets 2>/dev/null | \
       jq -e ".data.activeTargets[] | select(.labels.job == \"$target\")" > /dev/null 2>&1; then
        pass
    else
        warn "Optional target not configured"
    fi
done

# =============================================================================
# 4. Grafana Data Sources
# =============================================================================

print_header "4. Grafana Data Sources"

DATASOURCES=(
    "Prometheus"
    "Loki"
    "Tempo"
)

for ds in "${DATASOURCES[@]}"; do
    print_test "$ds data source"
    # Note: This requires Grafana API key or admin credentials
    # For now, just check if we can query the data source indirectly
    case $ds in
        "Prometheus")
            if curl -sf http://localhost:9090/api/v1/query?query=up > /dev/null 2>&1; then
                pass
            else
                fail "Cannot query Prometheus"
            fi
            ;;
        "Loki")
            if curl -sf http://localhost:3100/loki/api/v1/labels > /dev/null 2>&1; then
                pass
            else
                fail "Cannot query Loki"
            fi
            ;;
        "Tempo")
            if curl -sf http://localhost:3200/ready > /dev/null 2>&1; then
                pass
            else
                fail "Tempo not ready"
            fi
            ;;
    esac
done

# =============================================================================
# 5. Grafana Dashboards
# =============================================================================

print_header "5. Grafana Dashboards"

REQUIRED_DASHBOARDS=(
    "node-exporter-full.json"
    "docker-container-metrics.json"
    "traefik-official.json"
    "loki-dashboard.json"
    "uptime-kuma.json"
)

for dashboard in "${REQUIRED_DASHBOARDS[@]}"; do
    print_test "$dashboard"
    if [ -f "../../config/grafana/dashboards/$dashboard" ]; then
        pass
    else
        fail "Dashboard file not found"
    fi
done

# =============================================================================
# 6. Alert Rules
# =============================================================================

print_header "6. Alert Rules"

RULE_FILES=(
    "homelab.yml"
    "containers.yml"
    "services.yml"
)

for rule_file in "${RULE_FILES[@]}"; do
    print_test "$rule_file rules"
    if [ -f "../../config/prometheus/rules/$rule_file" ]; then
        # Check if rules are loaded
        if curl -sf http://localhost:9090/api/v1/rules 2>/dev/null | \
           jq -e ".data.groups[] | select(.file == \"$rule_file\")" > /dev/null 2>&1; then
            pass
        else
            warn "Rules file exists but not loaded in Prometheus"
        fi
    else
        fail "Rules file not found"
    fi
done

# =============================================================================
# 7. Log Collection
# =============================================================================

print_header "7. Log Collection"

# Check if Promtail is collecting logs
print_test "Promtail positions file"
if docker exec promtail test -f /tmp/positions.yaml 2>/dev/null; then
    pass
else
    warn "Positions file not found - Promtail may not be collecting logs yet"
fi

# Check if Loki has received logs
print_test "Loki has logs"
if curl -sf http://localhost:3100/loki/api/v1/labels 2>/dev/null | jq -e '.data | length > 0' > /dev/null 2>&1; then
    pass
else
    warn "No labels found in Loki - may need to wait for logs"
fi

# =============================================================================
# 8. Metrics Collection
# =============================================================================

print_header "8. Metrics Collection"

# Check if Prometheus has metrics
print_test "Prometheus has metrics"
METRIC_COUNT=$(curl -sf http://localhost:9090/api/v1/label/__name__/values 2>/dev/null | jq '.data | length' 2>/dev/null || echo "0")
if [ "$METRIC_COUNT" -gt 100 ]; then
    pass
    echo -e "  Found $METRIC_COUNT metric names"
else
    warn "Only $METRIC_COUNT metrics found - may need more time"
fi

# =============================================================================
# 9. Configuration Files
# =============================================================================

print_header "9. Configuration Files"

CONFIG_FILES=(
    "../../config/prometheus/prometheus.yml"
    "../../config/loki/loki-config.yml"
    "../../config/loki/promtail-config.yml"
    "../../config/tempo/tempo-config.yml"
    "../../config/alertmanager/alertmanager.yml"
    "../../config/grafana/provisioning/datasources/datasources.yml"
    "../../config/grafana/provisioning/dashboards/dashboards.yml"
)

for config_file in "${CONFIG_FILES[@]}"; do
    print_test "$(basename $config_file)"
    if [ -f "$config_file" ]; then
        pass
    else
        fail "Configuration file not found"
    fi
done

# =============================================================================
# 10. Network Connectivity
# =============================================================================

print_header "10. Network Connectivity"

# Check if monitoring network exists
print_test "Monitoring network"
if docker network inspect homelab-stack_monitoring > /dev/null 2>&1; then
    pass
else
    fail "Monitoring network not found"
fi

# Check if proxy network exists
print_test "Proxy network"
if docker network inspect proxy > /dev/null 2>&1; then
    pass
else
    warn "Proxy network not found - Traefik may not be running"
fi

# =============================================================================
# Summary
# =============================================================================

print_header "Verification Summary"

TOTAL=$((PASS + FAIL + WARN))
echo -e "Total tests: $TOTAL"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo -e "${YELLOW}Warnings: $WARN${NC}"

if [ $FAIL -eq 0 ]; then
    echo -e "\n${GREEN}✅ Observability stack is properly configured!${NC}\n"
    
    if [ $WARN -gt 0 ]; then
        echo -e "${YELLOW}Note: Some optional components or services may not be configured.${NC}"
    fi
    
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  1. Access Grafana: https://grafana.\${DOMAIN}"
    echo -e "  2. View dashboards in 'HomeLab' folder"
    echo -e "  3. Check alerts: https://prometheus.\${DOMAIN}/alerts"
    echo -e "  4. View logs in Grafana Explore tab"
    echo -e "  5. Configure Uptime Kuma: https://status.\${DOMAIN}"
    echo ""
    
    exit 0
else
    echo -e "\n${RED}❌ Observability stack has issues that need to be addressed.${NC}\n"
    echo -e "${BLUE}Troubleshooting steps:${NC}"
    echo -e "  1. Check container logs: docker compose logs <service>"
    echo -e "  2. Verify .env file configuration"
    echo -e "  3. Ensure all required services are running"
    echo -e "  4. Check network connectivity"
    echo -e "  5. Review documentation: ../../docs/observability.md"
    echo ""
    
    exit 1
fi
