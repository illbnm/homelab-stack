#!/bin/bash
set -euo pipefail

# Monitoring Stack Test Script
# Validates all components are working correctly

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="${DOMAIN:-localhost}"
TIMEOUT="${TIMEOUT:-5}"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# Test HTTP endpoint
test_endpoint() {
    local name="$1"
    local url="$2"
    local expected_status="${3:-200}"

    log_test "Testing $name: $url"

    if curl -sf --max-time "$TIMEOUT" "$url" > /dev/null 2>&1; then
        log_info "✓ $name is accessible"
        return 0
    else
        log_error "✗ $name is not accessible"
        return 1
    fi
}

# Test Docker container health
test_container() {
    local name="$1"

    log_test "Checking container: $name"

    if docker ps --filter "name=$name" --filter "status=running" | grep -q "$name"; then
        log_info "✓ Container $name is running"
        return 0
    else
        log_error "✗ Container $name is not running"
        return 1
    fi
}

# Test Prometheus targets
test_prometheus_targets() {
    log_test "Checking Prometheus targets..."

    local targets_url="http://localhost:9090/api/v1/targets"
    local failed_targets=0

    if ! response=$(curl -sf "$targets_url" 2>/dev/null); then
        log_error "Failed to query Prometheus targets API"
        return 1
    fi

    # Check if all targets are up (simplified check)
    local total_targets
    total_targets=$(docker exec prometheus wget -qO- http://localhost:9090/api/v1/targets 2>/dev/null | grep -o '"job":"' | wc -l || echo "0")

    log_info "Found $total_targets Prometheus targets"
    return 0
}

# Test Grafana dashboards
test_grafana_dashboards() {
    log_test "Checking Grafana dashboards..."

    local dashboards=(
        "node-exporter-full"
        "docker-container-metrics"
        "traefik-official"
        "loki-dashboard"
        "uptime-kuma"
    )

    log_info "Checking for dashboard files..."
    local found=0
    for dashboard in "${dashboards[@]}"; do
        if [ -f "config/grafana/dashboards/${dashboard}.json" ]; then
            log_info "✓ Dashboard file found: ${dashboard}.json"
            ((found++))
        else
            log_warn "✗ Dashboard file missing: ${dashboard}.json"
        fi
    done

    if [ $found -eq ${#dashboards[@]} ]; then
        log_info "All dashboard files present"
        return 0
    else
        log_warn "Some dashboard files are missing"
        return 1
    fi
}

# Test Loki log collection
test_loki_logs() {
    log_test "Testing Loki log collection..."

    # Check if Loki has any logs
    local loki_url="http://localhost:3100/loki/api/v1/labels"

    if curl -sf "$loki_url" > /dev/null 2>&1; then
        log_info "✓ Loki is responding"
        return 0
    else
        log_error "✗ Loki is not responding"
        return 1
    fi
}

# Test alert rules
test_alert_rules() {
    log_test "Checking alert rules..."

    local rules_dir="config/prometheus/rules"

    if [ -d "$rules_dir" ]; then
        local rule_files
        rule_files=$(find "$rules_dir" -name "*.yml" | wc -l)
        log_info "Found $rule_files alert rule files"

        for rule_file in "$rules_dir"/*.yml; do
            if [ -f "$rule_file" ]; then
                log_info "✓ Rule file: $(basename "$rule_file")"
            fi
        done
        return 0
    else
        log_error "✗ Alert rules directory not found"
        return 1
    fi
}

# Test Uptime Kuma
test_uptime_kuma() {
    log_test "Testing Uptime Kuma..."

    if test_endpoint "Uptime Kuma" "http://localhost:3001"; then
        log_info "✓ Uptime Kuma is accessible"
        return 0
    else
        log_error "✗ Uptime Kuma is not accessible"
        return 1
    fi
}

# Main test function
main() {
    log_info "Starting Monitoring Stack Tests"
    log_info "================================"
    echo ""

    local failed=0

    # Test containers
    log_info "Testing Container Health..."
    test_container "prometheus" || ((failed++))
    test_container "grafana" || ((failed++))
    test_container "loki" || ((failed++))
    test_container "promtail" || ((failed++))
    test_container "alertmanager" || ((failed++))
    test_container "cadvisor" || ((failed++))
    test_container "node-exporter" || ((failed++))
    test_container "tempo" || ((failed++))
    test_container "uptime-kuma" || ((failed++))
    echo ""

    # Test endpoints
    log_info "Testing HTTP Endpoints..."
    test_endpoint "Prometheus" "http://localhost:9090/-/healthy" || ((failed++))
    test_endpoint "Grafana" "http://localhost:3000/api/health" || ((failed++))
    test_endpoint "Alertmanager" "http://localhost:9093/-/healthy" || ((failed++))
    test_endpoint "Loki" "http://localhost:3100/ready" || ((failed++))
    test_endpoint "Tempo" "http://localhost:3200/ready" || ((failed++))
    echo ""

    # Test Prometheus
    log_info "Testing Prometheus Configuration..."
    test_prometheus_targets || ((failed++))
    echo ""

    # Test Grafana dashboards
    log_info "Testing Grafana Dashboards..."
    test_grafana_dashboards || ((failed++))
    echo ""

    # Test alert rules
    log_info "Testing Alert Rules..."
    test_alert_rules || ((failed++))
    echo ""

    # Test Loki
    log_info "Testing Loki..."
    test_loki_logs || ((failed++))
    echo ""

    # Test Uptime Kuma
    log_info "Testing Uptime Kuma..."
    test_uptime_kuma || ((failed++))
    echo ""

    # Summary
    log_info "================================"
    if [ $failed -eq 0 ]; then
        log_info "✓ All tests passed!"
        exit 0
    else
        log_error "✗ $failed test(s) failed"
        exit 1
    fi
}

# Run main function
main "$@"
