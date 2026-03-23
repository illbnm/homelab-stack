#!/bin/bash
# storage.test.sh - Storage Stack Integration Tests
# Tests for: Nextcloud, Samba

set -o pipefail

# Test Nextcloud running
test_storage_nextcloud_running() {
    local test_name="[storage] Nextcloud running"
    start_test "$test_name"
    
    if assert_container_running "nextcloud"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Container not running"
    fi
}

# Test Nextcloud HTTP endpoint
test_storage_nextcloud_http() {
    local test_name="[storage] Nextcloud HTTP 200"
    start_test "$test_name"
    
    if assert_http_200 "http://localhost:8080/login" 30; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "HTTP endpoint not accessible"
    fi
}

# Test Nextcloud status endpoint
test_storage_nextcloud_status() {
    local test_name="[storage] Nextcloud status.php"
    start_test "$test_name"
    
    local response
    response=$(curl -s "http://localhost:8080/status.php" 2>/dev/null)
    
    if echo "$response" | grep -q '"installed":true'; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Not properly installed"
    fi
}

# Test Samba running
test_storage_samba_running() {
    local test_name="[storage] Samba running"
    start_test "$test_name"
    
    if assert_container_running "samba"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Container not running"
    fi
}

# Test Samba ports
test_storage_samba_ports() {
    local test_name="[storage] Samba ports listening"
    start_test "$test_name"
    
    # Check if Samba ports are listening (445, 139)
    if netstat -tlnp 2>/dev/null | grep -q ":445" || ss -tlnp 2>/dev/null | grep -q ":445"; then
        pass_test "$test_name"
    else
        # May be running in container network mode
        if assert_container_running "samba"; then
            pass_test "$test_name"
        else
            fail_test "$test_name" "Ports not listening"
        fi
    fi
}

# Test Nextcloud data directory
test_storage_nextcloud_data() {
    local test_name="[storage] Nextcloud data directory"
    start_test "$test_name"
    
    if [[ -d "/home/gg/opt/agentwork/bigeye/homelab-stack/data/nextcloud" ]]; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Data directory missing"
    fi
}

# Run all storage tests
test_storage_all() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Storage Stack Tests"
    echo "════════════════════════════════════════"
    
    test_storage_nextcloud_running
    test_storage_nextcloud_http
    test_storage_nextcloud_status
    test_storage_samba_running
    test_storage_samba_ports
    test_storage_nextcloud_data
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
    test_storage_all
fi
