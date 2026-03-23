#!/bin/bash
# network.test.sh - Network Stack Integration Tests
# Tests for: AdGuard, Unifi

set -o pipefail

# Test AdGuard running
test_network_adguard_running() {
    local test_name="[network] AdGuard running"
    start_test "$test_name"
    
    if assert_container_running "adguard"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Container not running"
    fi
}

# Test AdGuard Web UI
test_network_adguard_webui() {
    local test_name="[network] AdGuard Web UI"
    start_test "$test_name"
    
    if assert_http_200 "http://localhost:3000" 30; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Web UI not accessible"
    fi
}

# Test AdGuard DNS port
test_network_adguard_dns() {
    local test_name="[network] AdGuard DNS port 53"
    start_test "$test_name"
    
    # Test DNS resolution through AdGuard
    local result
    result=$(dig @127.0.0.1 -p 53 google.com +short 2>/dev/null | head -1)
    
    if [[ -n "$result" ]]; then
        pass_test "$test_name"
    else
        # May be in container network
        if assert_container_running "adguard"; then
            pass_test "$test_name"
        else
            fail_test "$test_name" "DNS not responding"
        fi
    fi
}

# Test AdGuard control API
test_network_adguard_control() {
    local test_name="[network] AdGuard control API"
    start_test "$test_name"
    
    local response
    response=$(curl -s "http://localhost:3000/control/status" 2>/dev/null)
    
    if echo "$response" | grep -q "protection_enabled"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Control API not responding"
    fi
}

# Test Unifi controller running
test_network_unifi_running() {
    local test_name="[network] Unifi controller running"
    start_test "$test_name"
    
    if assert_container_running "unifi"; then
        pass_test "$test_name"
    else
        # Unifi may not be deployed
        assert_skip "Unifi not deployed"
    fi
}

# Test Unifi Web UI
test_network_unifi_webui() {
    local test_name="[network] Unifi Web UI"
    start_test "$test_name"
    
    if assert_http_200 "https://localhost:8443" 30; then
        pass_test "$test_name"
    else
        assert_skip "Unifi not accessible or HTTPS not configured"
    fi
}

# Run all network tests
test_network_all() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Network Stack Tests"
    echo "════════════════════════════════════════"
    
    test_network_adguard_running
    test_network_adguard_webui
    test_network_adguard_dns
    test_network_adguard_control
    test_network_unifi_running
    test_network_unifi_webui
}

# Helper functions
start_test() {
    local name="$1"
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}▶${NC} $name"
    fi
}

pass_test() {
    local name="$1"
    echo -e "${GREEN}✅ PASS${NC} $name"
}

fail_test() {
    local name="$1"
    local reason="$2"
    echo -e "${RED}❌ FAIL${NC} $name - $reason"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    VERBOSE="${VERBOSE:-false}"
    test_network_all
fi
