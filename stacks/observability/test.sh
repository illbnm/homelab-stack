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
failed_tests=0

# Function to test a service health
test_service_health() {
    local service=$1
    local url=$2
    local expected_status=${3:-200}

    echo -n "Testing $service at $url..."
    response=$(curl -sf -o /dev/null -w "$url" 2>&1)
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ $service is healthy${NC}"
        ((total_tests++))
        return 0
    else
        echo -e "${RED}❌ $service is unhealthy (status: $exit_code)${NC}"
        ((failed_tests++))
        return 1
    fi
}

# Function to test Prometheus targets
test_prometheus_targets() {
    echo -n "\n📊 Testing Prometheus targets..."
    local url="http://prometheus:9090/api/v1/targets"

    response=$(curl -sf "$url" 2>&1)

    if [ $? -eq 0 ]; then
        targets=$(echo "$response" | jq -r '.data.activeAlerts // [] | length)

        if [ ${#targets[@]} -eq 0 ]; then
            echo -e "${GREEN}✅ All Prometheus targets are UP${NC}"
            return 0
        else
            echo -e "${RED}❌ Some Prometheus targets are down${NC}"
            echo "Failed targets:"
            echo "$targets"
            ((failed_tests++))
            return 1
        fi
    else
        echo -e "${RED}❌ Failed to query Prometheus targets${NC}"
        ((failed_tests++))
        return 1
    fi
}

# Function to test Grafana dashboards
test_grafana_dashboards() {
    echo -n "\n📊 Testing Grafana dashboards..."
    local url="http://grafana:3000/api/search?query=dashboards"

    response=$(curl -sf -u "admin:admin" "$url" 2>&1)

    if [ $? -eq 0 ]; then
        dashboards=$(echo "$response" | jq -r '.[] | length)

        # Check for required dashboards
        local required_dashboards=("Node Exporter Full" "Docker Container" "Traefik Official" "Loki Dashboard" "Uptime Kuma")

        local found_dashboards=()

        for dashboard in "${required_dashboards[@]}"; do
            for i in $(seq 0 $(($dashboards | length)); do
                if [[ ${dashboards[$i].title} == *"$dashboard"* ]]; then
                    found_dashboards+=" $dashboard"
                    break
                fi
            done
        done

        if [ ${#found_dashboards[@]} -eq ${#required_dashboards[@]} ]; then
            echo -e "${GREEN}✅ All required dashboards are provisioned${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️ Some dashboards are missing:${NC}"
            echo "Missing: $(comm -S "${required_dashboards[@]}" | grep -v "$found_dashboards" || tr -d ' ' | sort -u)
            ((failed_tests++))
            return 1
        fi
    else
        echo -e "${RED}❌ Failed to query Grafana dashboards${NC}"
        ((failed_tests++))
        return 1
    fi
}

# Function to test Loki log collection
test_loki_logs() {
    echo -n "\n📊 Testing Loki log collection..."
    local url="http://loki:3100/loki/api/v1/labels"

    response=$(curl -sf "$url" 2>&1)

    if [ $? -eq 0 ]; then
        labels=$(echo "$response" | jq -r '.data[] | length)

        if [ ${#labels[@]} -gt 0 ]; then
            echo -e "${GREEN}✅ Loki is collecting logs${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️ Loki is not collecting any logs yet${NC}"
            ((failed_tests++))
            return 1
        fi
    else
        echo -e "${RED}❌ Failed to query Loki labels${NC}"
        ((failed_tests++))
        return 1
    fi
}

# Function to test alerting pipeline
test_alerting() {
    echo -n "\n🔔 Testing alerting pipeline..."
    local url="http://alertmanager:9093/api/v2/alerts"

    response=$(curl -sf "$url" 2>&1)

    if [ $? -eq 0 ]; then
        alerts=$(echo "$response" | jq -r '.[] | length)

        if [ ${#alerts[@]} -eq 0 ]; then
            echo -e "${GREEN}✅ Alertmanager is ready${NC}"
            echo -e "Alert rules loaded:"
            echo "  $(curl -s http://prometheus:9090/api/v1/rules | jq -r '.groups[].name')"
            return 0
        else
            echo -e "${RED}❌ No alert rules loaded${NC}"
            ((failed_tests++))
            return 1
        fi
    else
        echo -e "${RED}❌ Failed to query Alertmanager${NC}"
        ((failed_tests++))
        return 1
    fi
}

# Main test execution
main() {
    echo "🧪 Starting comprehensive observability tests..."
    echo "================================"
    echo ""

    # Test service health
    echo "📋 Phase 1: Service Health Checks"
    echo "================================"

    test_service_health "Prometheus" "http://prometheus:9090/-/healthy"
    test_service_health "Grafana" "http://grafana:3000/api/health"
    test_service_health "Loki" "http://loki:3100/ready"
    test_service_health "Tempo" "http://tempo:3200/ready"
    test_service_health "Alertmanager" "http://alertmanager:9093/-/healthy"
    test_service_health "Uptime Kuma" "http://uptime-kuma:3001"
    test_service_health "cAdvisor" "http://cadvisor:8080/healthz"
    test_service_health "Node Exporter" "http://node-exporter:9100/metrics"
    test_service_health "Grafana OnCall" "http://oncall:8080/health"

    echo ""
    echo "📊 Phase 2: Prometheus Targets"
    echo "================================="
    test_prometheus_targets

    echo ""
    echo "📊 Phase 3: Grafana Dashboards"
    echo "================================="
    test_grafana_dashboards

    echo ""
    echo "📊 Phase 4: Log Collection"
    echo "================================="
    test_loki_logs

    echo ""
    echo "🔔 Phase 5: Alerting Pipeline"
    echo "================================="
    test_alerting

    echo ""
    echo "================================"
    echo "📊 Test Summary"
    echo "================================"
    echo "Total tests: $total_tests"
    echo "Passed: $((total_tests - failed_tests))"
    echo "Failed: $failed_tests"
    echo ""

    if [ $failed_tests -eq 0 ]; then
        echo -e "${RED}❌ Some tests failed. Please check the logs above.${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ All tests passed! Observability stack is ready.${NC}"
        exit 0
    fi
}
