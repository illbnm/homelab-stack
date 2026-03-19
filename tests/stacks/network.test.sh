#!/bin/bash
# network.test.sh - Network Stack 集成测试
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_traefik_running() {
    echo "[network] Testing Traefik running..."
    assert_container_running "traefik"
}

test_traefik_http() {
    echo "[network] Testing Traefik HTTP..."
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "http://localhost:8080/api/version" 2>/dev/null)
    if [[ "$http_code" == "200" ]]; then
        echo -e "${GREEN}✅ PASS${NC}"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} Traefik API returned $http_code"
        return 1
    fi
}

test_adguard_running() {
    echo "[network] Testing AdGuard running..."
    assert_container_running "adguard"
}

test_adguard_http() {
    echo "[network] Testing AdGuard HTTP..."
    assert_http_200 "http://localhost:3000/control/status" 30
}

test_pihole_running() {
    echo "[network] Testing Pi-hole running..."
    assert_container_running "pihole" || return 0  # Optional
}

test_pihole_http() {
    echo "[network] Testing Pi-hole HTTP..."
    assert_http_200 "http://localhost:8082/admin" 30 || return 0
}

test_wireguard_running() {
    echo "[network] Testing WireGuard running..."
    assert_container_running "wireguard" || return 0  # Optional
}

test_compose_exists() {
    echo "[network] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/network/docker-compose.yml"
}

run_network_tests() {
    print_header "HomeLab Stack — Network Tests"
    
    test_compose_exists || true
    test_traefik_running || true
    test_traefik_http || true
    test_adguard_running || true
    test_adguard_http || true
    test_pihole_running || true
    test_pihole_http || true
    test_wireguard_running || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_network_tests
fi
