#!/bin/bash

# Network Stack Validation Script
# Tests DNS, VPN, proxy, and monitoring services

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_test() { echo -e "  ${YELLOW}[?]${NC} Testing: $1"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

check_container() {
    local container=$1
    print_test "Container $container"
    
    if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "^$container\$"; then
        local status=$(docker ps --filter "name=$container" --format "{{.Status}}")
        if echo "$status" | grep -q "healthy\|Up"; then
            print_success "$container: $status"
            return 0
        else
            print_warning "$container: $status"
            return 1
        fi
    else
        print_error "$container not running"
        return 2
    fi
}

test_dns() {
    print_test "DNS Resolution"
    
    # Test AdGuard
    if dig @localhost example.com +short >/dev/null 2>&1; then
        print_success "DNS resolution working"
    else
        print_error "DNS resolution failed"
        return 1
    fi
    
    # Test specific services
    if curl -s -f http://localhost:3000 >/dev/null 2>&1; then
        print_success "AdGuard Web UI accessible"
    else
        print_warning "AdGuard UI not accessible"
    fi
    
    return 0
}

test_vpn() {
    print_test "WireGuard VPN"
    
    # Check WireGuard port
    if netstat -tuln | grep ':51820 ' >/dev/null; then
        print_success "WireGuard port 51820 listening"
    else
        print_error "WireGuard port not listening"
        return 1
    fi
    
    # Check if WireGuard interface exists in container
    if docker exec wireguard wg show >/dev/null 2>&1; then
        print_success "WireGuard running in container"
    else
        print_warning "WireGuard not configured in container"
    fi
    
    return 0
}

test_proxy() {
    print_test "Traefik Proxy"
    
    if curl -s -f http://localhost:8080/api/rawdata >/dev/null 2>&1; then
        print_success "Traefik API accessible"
    else
        print_error "Traefik API not accessible"
        return 1
    fi
    
    # Check HTTP/HTTPS ports
    if netstat -tuln | grep ':80 ' >/dev/null; then
        print_success "HTTP port 80 listening"
    else
        print_warning "HTTP port 80 not listening"
    fi
    
    if netstat -tuln | grep ':443 ' >/dev/null; then
        print_success "HTTPS port 443 listening"
    else
        print_warning "HTTPS port 443 not listening"
    fi
    
    return 0
}

test_monitoring() {
    print_test "Monitoring Services"
    
    # Netdata
    if curl -s -f http://localhost:19999/api/v1/info >/dev/null 2>&1; then
        print_success "Netdata API working"
    else
        print_error "Netdata not responding"
        return 1
    fi
    
    # SmokePing
    if curl -s -f http://localhost:8081 >/dev/null 2>&1; then
        print_success "SmokePing accessible"
    else
        print_warning "SmokePing not accessible"
    fi
    
    # Node Exporter
    if curl -s -f http://localhost:9100/metrics >/dev/null 2>&1; then
        print_success "Node Exporter metrics available"
    else
        print_warning "Node Exporter not responding"
    fi
    
    return 0
}

test_network_connectivity() {
    print_test "Network Connectivity"
    
    # Test external connectivity from containers
    local containers=("adguard-home" "unbound" "wireguard")
    local all_ok=true
    
    for container in "${containers[@]}"; do
        if docker exec "$container" ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            print_success "$container has external connectivity"
        else
            print_warning "$container may lack external connectivity"
            all_ok=false
        fi
    done
    
    if $all_ok; then
        print_success "All containers have network connectivity"
    fi
    
    return 0
}

run_all_tests() {
    local passed=0 failed=0 warning=0 total=0
    
    echo "=== Network Stack Validation Report ==="
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo ""
    
    local tests=(
        "check_container adguard-home"
        "check_container unbound"
        "check_container wireguard"
        "check_container traefik"
        "check_container netdata"
        "test_dns"
        "test_vpn"
        "test_proxy"
        "test_monitoring"
        "test_network_connectivity"
    )
    
    for test_cmd in "${tests[@]}"; do
        total=$((total + 1))
        local test_name=$(echo "$test_cmd" | sed 's/^test_//; s/^check_container //')
        
        echo "Test $total: $test_name"
        
        if output=$(eval "$test_cmd" 2>&1); then
            passed=$((passed + 1))
            echo "  Result: PASS"
        else
            local exit_code=$?
            if [ $exit_code -eq 1 ]; then
                warning=$((warning + 1))
                echo "  Result: WARNING"
            else
                failed=$((failed + 1))
                echo "  Result: FAIL"
            fi
        fi
        
        [ -n "$output" ] && echo "$output" | sed 's/^/    /'
        echo ""
    done
    
    echo "=== Summary ==="
    echo "Total Tests: $total"
    echo "Passed: $passed"
    echo "Warnings: $warning"
    echo "Failed: $failed"
    echo ""
    
    if [ $failed -eq 0 ]; then
        if [ $warning -eq 0 ]; then
            echo -e "${GREEN}All tests passed! Network stack is fully operational.${NC}"
            return 0
        else
            echo -e "${YELLOW}Tests passed with warnings. Network stack is operational but may need attention.${NC}"
            return 1
        fi
    else
        echo -e "${RED}Some tests failed. Network stack has issues that need to be addressed.${NC}"
        return 2
    fi
}

main() {
    if ! command_exists docker; then
        print_error "Docker not found"
        exit 1
    fi
    
    if [ ! -f "$PROJECT_ROOT/docker-compose.network.yml" ]; then
        print_error "Not in network stack directory"
        exit 1
    fi
    
    run_all_tests
}

main "$@"