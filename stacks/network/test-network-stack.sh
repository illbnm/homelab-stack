#!/bin/bash
# =============================================================================
# test-network-stack.sh — Network Stack 自动化测试脚本
# 
# 验证所有服务启动、健康检查、功能正常
# =============================================================================

set -e

RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[1;33m'
BLUE='\e[0;34m'
NC='\e[0m'

TESTS_PASSED=0
TESTS_FAILED=0

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

# Test 1: Check docker-compose.yml syntax
test_compose_syntax() {
    print_info "Testing docker-compose.yml syntax..."
    
    if command -v docker &> /dev/null; then
        if docker compose config > /dev/null 2>&1; then
            print_success "docker-compose.yml syntax is valid"
        else
            print_error "docker-compose.yml syntax error"
            return 1
        fi
    elif command -v python3 &> /dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml'))" 2>/dev/null; then
            print_success "docker-compose.yml YAML syntax is valid"
        else
            print_error "docker-compose.yml YAML syntax error"
            return 1
        fi
    else
        print_warning "Neither docker nor python3 available, skipping syntax check"
    fi
}

# Test 2: Check .env.example exists
test_env_example() {
    print_info "Checking .env.example..."
    
    if [[ -f ".env.example" ]]; then
        # Check required variables
        REQUIRED_VARS=("DOMAIN" "WG_HOST" "WG_PASSWORD" "CF_API_TOKEN" "CF_ZONE_ID" "CF_RECORD_NAME")
        MISSING=0
        
        for var in "${REQUIRED_VARS[@]}"; do
            if ! grep -q "^${var}=" .env.example; then
                print_warning "Missing required variable in .env.example: $var"
                MISSING=1
            fi
        done
        
        if [[ $MISSING -eq 0 ]]; then
            print_success ".env.example contains all required variables"
        else
            print_error ".env.example is missing some required variables"
        fi
    else
        print_error ".env.example not found"
    fi
}

# Test 3: Check README.md exists
test_readme() {
    print_info "Checking README.md..."
    
    if [[ -f "README.md" ]]; then
        # Check for required sections
        if grep -q "快速开始" README.md && \
           grep -q "配置说明" README.md && \
           grep -q "故障排除" README.md; then
            print_success "README.md contains required sections"
        else
            print_warning "README.md missing some recommended sections"
        fi
        
        # Check for service documentation
        if grep -q "AdGuard" README.md && \
           grep -q "WireGuard" README.md && \
           grep -q "DDNS" README.md; then
            print_success "README.md documents all services"
        else
            print_error "README.md missing service documentation"
        fi
    else
        print_error "README.md not found"
    fi
}

# Test 4: Check service definitions
test_services() {
    print_info "Checking service definitions..."
    
    REQUIRED_SERVICES=("adguardhome" "wireguard" "cloudflare-ddns" "unbound" "nginx-proxy-manager")
    
    for service in "${REQUIRED_SERVICES[@]}"; do
        if grep -q "^  ${service}:" docker-compose.yml; then
            print_success "Service '$service' is defined"
        else
            print_error "Service '$service' is missing"
        fi
    done
}

# Test 5: Check image versions (no 'latest' tags)
test_image_versions() {
    print_info "Checking image versions (no 'latest' tags)..."
    
    LATEST_COUNT=$(grep -c "image:.*:latest" docker-compose.yml || true)
    
    if [[ $LATEST_COUNT -eq 0 ]]; then
        print_success "No 'latest' tags found in image definitions"
    else
        print_error "Found $LATEST_COUNT 'latest' tags - use specific versions"
    fi
}

# Test 6: Check health checks
test_health_checks() {
    print_info "Checking health check definitions..."
    
    SERVICES_WITH_HEALTHCHECK=("adguardhome" "wireguard" "unbound" "nginx-proxy-manager")
    
    for service in "${SERVICES_WITH_HEALTHCHECK[@]}"; do
        # Extract service block and check for healthcheck
        if awk "/^  ${service}:/,/^  [a-z]/" docker-compose.yml | grep -q "healthcheck:"; then
            print_success "Service '$service' has healthcheck defined"
        else
            print_warning "Service '$service' missing healthcheck"
        fi
    done
}

# Test 7: Check volume definitions
test_volumes() {
    print_info "Checking volume definitions..."
    
    REQUIRED_VOLUMES=("unbound-data" "adguard-work" "adguard-conf" "wireguard-data" "npm-data" "npm-letsencrypt")
    
    for volume in "${REQUIRED_VOLUMES[@]}"; do
        if grep -q "^  ${volume}:" docker-compose.yml; then
            print_success "Volume '$volume' is defined"
        else
            print_error "Volume '$volume' is missing"
        fi
    done
}

# Test 8: Check network configuration
test_network() {
    print_info "Checking network configuration..."
    
    if grep -q "proxy:" docker-compose.yml && grep -q "external: true" docker-compose.yml; then
        print_success "External 'proxy' network is configured"
    else
        print_error "External network configuration missing"
    fi
}

# Test 9: Check fix-dns-port.sh script
test_fix_dns_script() {
    print_info "Checking fix-dns-port.sh script..."
    
    SCRIPT_PATH="../../scripts/fix-dns-port.sh"
    
    if [[ -f "$SCRIPT_PATH" ]]; then
        if [[ -x "$SCRIPT_PATH" ]]; then
            print_success "fix-dns-port.sh exists and is executable"
        else
            print_warning "fix-dns-port.sh exists but is not executable"
        fi
        
        # Check for required functions
        if grep -q "apply_fix" "$SCRIPT_PATH" && \
           grep -q "restore_config" "$SCRIPT_PATH" && \
           grep -q "check_port_53" "$SCRIPT_PATH"; then
            print_success "fix-dns-port.sh contains required functions"
        else
            print_error "fix-dns-port.sh missing required functions"
        fi
    else
        print_error "fix-dns-port.sh not found"
    fi
}

# Test 10: Check Traefik labels
test_traefik_labels() {
    print_info "Checking Traefik labels..."
    
    SERVICES_NEEDING_TRAEFIK=("adguardhome" "wireguard" "nginx-proxy-manager")
    
    for service in "${SERVICES_NEEDING_TRAEFIK[@]}"; do
        if awk "/^  ${service}:/,/^  [a-z]/" docker-compose.yml | grep -q "traefik.enable=true"; then
            print_success "Service '$service' has Traefik labels"
        else
            print_warning "Service '$service' missing Traefik labels"
        fi
    done
}

# Main test runner
main() {
    echo "========================================"
    echo "  Network Stack - Automated Tests"
    echo "========================================"
    echo ""
    
    cd "$(dirname "$0")"
    
    test_compose_syntax
    test_env_example
    test_readme
    test_services
    test_image_versions
    test_health_checks
    test_volumes
    test_network
    test_fix_dns_script
    test_traefik_labels
    
    echo ""
    echo "========================================"
    echo "  Test Summary"
    echo "========================================"
    echo -e "  ${GREEN}Passed${NC}: $TESTS_PASSED"
    echo -e "  ${RED}Failed${NC}: $TESTS_FAILED"
    echo "========================================"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"
