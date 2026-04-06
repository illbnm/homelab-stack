#!/bin/bash
# Observability Stack Validation Script
# Verifies all components are working correctly

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
WARNINGS=0

echo -e "${BLUE}=== Observability Stack Validation ===${NC}"
echo ""

# Function to check service health
check_service() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    if curl -sf --max-time 10 "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $name is healthy"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $name is NOT healthy"
        ((FAILED++))
        return 1
    fi
}

# Function to check container status
check_container() {
    local name=$1
    
    if docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null | grep -q "running"; then
        echo -e "${GREEN}✓${NC} Container $name is running"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} Container $name is NOT running"
        ((FAILED++))
        return 1
    fi
}

echo -e "${YELLOW}1. Checking Container Status...${NC}"
check_container "prometheus"
check_container "grafana"
check_container "loki"
check_container "promtail"
check_container "tempo"
check_container "alertmanager"
check_container "cadvisor"
check_container "node-exporter"
check_container "uptime-kuma"
echo ""

echo -e "${YELLOW}2. Checking Service Health Endpoints...${NC}"
check_service "Prometheus" "http://localhost:9090/-/healthy"
check_service "Grafana" "http://localhost:3000/api/health"
check_service "Loki" "http://localhost:3100/ready"
check_service "Tempo" "http://localhost:3200/ready"
check_service "Alertmanager" "http://localhost:9093/-/healthy"
check_service "cAdvisor" "http://localhost:8080/healthz"
check_service "Node Exporter" "http://localhost:9100/metrics"
echo ""

echo -e "${YELLOW}3. Checking Prometheus Targets...${NC}"
TARGETS=$(curl -sf http://localhost:9090/api/v1/targets | grep -c '"health":"up"' || echo "0")
if [ "$TARGETS" -gt 5 ]; then
    echo -e "${GREEN}✓${NC} Prometheus has $TARGETS healthy targets"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Prometheus only has $TARGETS healthy targets (expected >5)"
    ((FAILED++))
fi
echo ""

echo -e "${YELLOW}4. Checking Grafana Dashboards...${NC}"
DASHBOARD_COUNT=$(ls -1 config/grafana/dashboards/*.json 2>/dev/null | wc -l)
if [ "$DASHBOARD_COUNT" -ge 5 ]; then
    echo -e "${GREEN}✓${NC} Found $DASHBOARD_COUNT dashboard files"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Only found $DASHBOARD_COUNT dashboard files (expected >=5)"
    ((WARNINGS++))
fi
echo ""

echo -e "${YELLOW}5. Checking Alert Rules...${NC}"
RULE_COUNT=$(ls -1 config/prometheus/rules/*.yml 2>/dev/null | wc -l)
if [ "$RULE_COUNT" -ge 3 ]; then
    echo -e "${GREEN}✓${NC} Found $RULE_COUNT alert rule files"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Only found $RULE_COUNT alert rule files (expected >=3)"
    ((WARNINGS++))
fi
echo ""

echo -e "${YELLOW}6. Checking Loki Configuration...${NC}"
if [ -f "config/loki/loki-config.yml" ] && [ -f "config/loki/promtail-config.yml" ]; then
    echo -e "${GREEN}✓${NC} Loki and Promtail configurations exist"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Loki or Promtail configuration missing"
    ((FAILED++))
fi
echo ""

echo -e "${YELLOW}7. Testing Loki Log Query...${NC}"
if curl -sf "http://localhost:3100/loki/api/v1/query_range" \
    --data-urlencode 'query={job="varlogs"}' \
    --data-urlencode 'start=1h' \
    --data-urlencode 'end=now' > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Loki log query successful"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Loki log query failed (may need time to ingest logs)"
    ((WARNINGS++))
fi
echo ""

echo -e "${YELLOW}8. Checking Uptime Kuma Setup Script...${NC}"
if [ -x "scripts/uptime-kuma-setup.sh" ]; then
    echo -e "${GREEN}✓${NC} Uptime Kuma setup script exists and is executable"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Uptime Kuma setup script missing or not executable"
    ((WARNINGS++))
fi
echo ""

# Summary
echo -e "${BLUE}=== Validation Summary ===${NC}"
echo -e "Passed:   ${GREEN}${PASSED}${NC}"
echo -e "Failed:   ${RED}${FAILED}${NC}"
echo -e "Warnings: ${YELLOW}${WARNINGS}${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please review the output above.${NC}"
    exit 1
fi
