#!/bin/bash
# notifications.test.sh - Notifications Stack Integration Tests
# Tests for: ntfy, Gotify

set -o pipefail

# Test ntfy running
test_notifications_ntfy_running() {
    local test_name="[notifications] ntfy running"
    start_test "$test_name"
    
    if assert_container_running "ntfy"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Container not running"
    fi
}

# Test ntfy Web UI
test_notifications_ntfy_webui() {
    local test_name="[notifications] ntfy Web UI"
    start_test "$test_name"
    
    if assert_http_200 "http://localhost:80" 30; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Web UI not accessible"
    fi
}

# Test ntfy health endpoint
test_notifications_ntfy_health() {
    local test_name="[notifications] ntfy health endpoint"
    start_test "$test_name"
    
    if assert_http_response "http://localhost:80/v1/health" "" 30; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Health endpoint not responding"
    fi
}

# Test ntfy publish endpoint
test_notifications_ntfy_publish() {
    local test_name="[notifications] ntfy publish test"
    start_test "$test_name"
    
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:80/test-topic" -d "test message" 2>/dev/null)
    
    if [[ "$response" == "200" ]]; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Publish failed (HTTP $response)"
    fi
}

# Test Gotify running
test_notifications_gotify_running() {
    local test_name="[notifications] Gotify running"
    start_test "$test_name"
    
    if assert_container_running "gotify"; then
        pass_test "$test_name"
    else
        assert_skip "Gotify not deployed"
    fi
}

# Test Gotify Web UI
test_notifications_gotify_webui() {
    local test_name="[notifications] Gotify Web UI"
    start_test "$test_name"
    
    if assert_http_200 "http://localhost:8085" 30; then
        pass_test "$test_name"
    else
        assert_skip "Gotify not accessible"
    fi
}

# Test Gotify API
test_notifications_gotify_api() {
    local test_name="[notifications] Gotify API /version"
    start_test "$test_name"
    
    local response
    response=$(curl -s "http://localhost:8085/version" 2>/dev/null)
    
    if echo "$response" | grep -q "version"; then
        pass_test "$test_name"
    else
        assert_skip "Gotify API not responding"
    fi
}

# Test notify.sh script exists
test_notifications_script() {
    local test_name="[notifications] notify.sh script exists"
    start_test "$test_name"
    
    if [[ -f "/home/gg/opt/agentwork/bigeye/homelab-stack/scripts/notify.sh" ]]; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Script not found"
    fi
}

# Run all notifications tests
test_notifications_all() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Notifications Stack Tests"
    echo "════════════════════════════════════════"
    
    test_notifications_ntfy_running
    test_notifications_ntfy_webui
    test_notifications_ntfy_health
    test_notifications_ntfy_publish
    test_notifications_gotify_running
    test_notifications_gotify_webui
    test_notifications_gotify_api
    test_notifications_script
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
    test_notifications_all
fi
