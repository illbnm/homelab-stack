#!/bin/bash

# Comprehensive test script for Observability Stack
# Tests all services, alerting, dashboards, and log collection

set -e

echo "🧪 Starting Observability Stack Tests..."
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Test counter
total_tests=0
passed_tests=0
failed_tests=0

# Function to test a service health
test_service_health() {
    local service=$1
    local url=$2
    
    echo -n "Testing $service... "
    
    if curl -sf -o /dev/null "$url" 2>&1; then
        echo -e "${GREEN}✅ healthy${NC}"
        total_tests=$((total_tests + 1))
        passed_tests=$((passed_tests + 1))
        return 0
    else
        echo -e "${RED}❌ unhealthy${NC}"
        total_tests=$((total_tests + 1))
        failed_tests=$((failed_tests + 1))
        return 1
    fi
}

# Function to test Prometheus targets
test_prometheus_targets() {
    echo ""
    echo "📊 Testing Prometheus targets..."
    
    if command -v jq &>/dev/null; then
        local response=$(curl -sf "http://localhost:9090/api/v1/targets" 2>&1)
        
        if [ $? -eq 0 ]; then
            # Count active targets
            local active_targets=$(echo "$response" | jq -r '.data.activeTargets | length' 2>/dev/null || echo "0")
            local up_targets=$(echo "$response" | jq -r '[.data.activeTargets[] | select(.health == "up")] | length' 2>/dev/null || echo "0")
            
            echo "  Active targets: $active_targets"
            echo "  Healthy targets: $up_targets"
            
            if [ "$active_targets" -gt 0 ] && [ "$up_targets" -gt 0 ]; then
                echo -e "${GREEN}✅ Prometheus targets are healthy${NC}"
                total_tests=$((total_tests + 1))
                passed_tests=$((passed_tests + 1))
                return 0
            fi
        fi
    fi
    
    echo -e "${YELLOW}⚠️ Could not verify Prometheus targets (jq not available or service not running)${NC}"
    total_tests=$((total_tests + 1))
    failed_tests=$((failed_tests + 1))
    return 1
}

# Function to test Grafana dashboards
test_grafana_dashboards() {
    echo ""
    echo "📊 Testing Grafana dashboards..."
    
    local dashboard_dir="../../config/grafana/dashboards"
    local dashboard_count=$(ls -1 "$dashboard_dir"/*.json 2>/dev/null | wc -l)
    
    echo "  Dashboard files found: $dashboard_count"
    
    if [ "$dashboard_count" -ge 5 ]; then
        echo -e "${GREEN}✅ Grafana dashboards are provisioned${NC}"
        total_tests=$((total_tests + 1))
        passed_tests=$((passed_tests + 1))
        return 0
    else
        echo -e "${YELLOW}⚠️ Not all dashboards are present (expected 5, found $dashboard_count)${NC}"
        total_tests=$((total_tests + 1))
        failed_tests=$((failed_tests + 1))
        return 1
    fi
}

# Function to test Loki log collection
test_loki_logs() {
    echo ""
    echo "📊 Testing Loki log collection..."
    
    if curl -sf "http://localhost:3100/ready" &>/dev/null; then
        echo -e "${GREEN}✅ Loki is ready${NC}"
        total_tests=$((total_tests + 1))
        passed_tests=$((passed_tests + 1))
        return 0
    else
        echo -e "${RED}❌ Loki is not ready${NC}"
        total_tests=$((total_tests + 1))
        failed_tests=$((failed_tests + 1))
        return 1
    fi
}

# Function to test alerting pipeline
test_alerting() {
    echo ""
    echo "🔔 Testing alerting pipeline..."
    
    if curl -sf "http://localhost:9093/-/healthy" &>/dev/null; then
        echo -e "${GREEN}✅ Alertmanager is healthy${NC}"
        total_tests=$((total_tests + 1))
        passed_tests=$((passed_tests + 1))
        
        # Check alert rules
        if command -v jq &>/dev/null; then
            local rules_count=$(curl -sf "http://localhost:9090/api/v1/rules" 2>&1 | jq -r '.data.groups | length' 2>/dev/null || echo "0")
            echo "  Alert rule groups loaded: $rules_count"
        fi
        
        return 0
    else
        echo -e "${RED}❌ Alertmanager is not healthy${NC}"
        total_tests=$((total_tests + 1))
        failed_tests=$((failed_tests + 1))
        return 1
    fi
}

# Main test execution
main() {
    echo "================================"
    echo "Phase 1: Service Health Checks"
    echo "================================"
    echo ""

    # Test service health
    test_service_health "Prometheus" "http://localhost:9090/-/healthy"
    test_service_health "Grafana" "http://localhost:3000/api/health"
    test_service_health "Loki" "http://localhost:3100/ready"
    test_service_health "Tempo" "http://localhost:3200/ready"
    test_service_health "Alertmanager" "http://localhost:9093/-/healthy"
    test_service_health "Uptime Kuma" "http://localhost:3001"
    test_service_health "cAdvisor" "http://localhost:8080/healthz"
    test_service_health "Node Exporter" "http://localhost:9100/metrics"

    echo ""
    echo "================================"
    echo "Phase 2: Prometheus Targets"
    echo "================================"
    test_prometheus_targets

    echo ""
    echo "================================"
    echo "Phase 3: Grafana Dashboards"
    echo "================================"
    test_grafana_dashboards

    echo ""
    echo "================================"
    echo "Phase 4: Log Collection"
    echo "================================"
    test_loki_logs

    echo ""
    echo "================================"
    echo "Phase 5: Alerting Pipeline"
    echo "================================"
    test_alerting

    echo ""
    echo "================================"
    echo "📊 Test Summary"
    echo "================================"
    echo "Total tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo ""

    if [ $failed_tests -eq 0 ]; then
        echo -e "${GREEN}✅ All tests passed! Observability stack is ready.${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed. Please check the logs above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
