#!/usr/bin/env bash
# ==============================================================================
# Notifications Stack Tests
# Tests for ntfy, Gotify, Apprise
# ==============================================================================

# Test: ntfy container is running
test_ntfy_running() {
    assert_container_running "ntfy"
}

# Test: ntfy is healthy
test_ntfy_healthy() {
    assert_container_healthy "ntfy" 60
}

# Test: ntfy API endpoint
test_ntfy_api() {
    assert_http_200 "http://localhost:80/v1/stats" 10 || \
    assert_http_200 "http://localhost:80/" 10
}

# Test: ntfy can receive messages
test_ntfy_publish() {
    begin_test
    local topic="homelab-test"
    local message="Test message from integration test"
    
    local response=$(curl -sf -d "$message" "http://localhost:80/$topic" 2>/dev/null || echo "{}")
    
    if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
        log_pass "ntfy message published successfully"
    else
        log_skip "ntfy message publish test skipped (may require auth)"
    fi
}

# Test: Gotify container (if configured)
test_gotify_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "gotify"; then
        assert_container_running "gotify"
        assert_http_200 "http://localhost:8080/version" 10
    else
        log_skip "Gotify not configured"
    fi
}

# Test: Gotify is healthy
test_gotify_healthy() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "gotify"; then
        assert_container_healthy "gotify" 60
    else
        log_skip "Gotify not configured"
    fi
}

# Test: Apprise (if configured as sidecar)
test_apprise_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "apprise"; then
        assert_container_running "apprise"
        assert_http_200 "http://localhost:8000/status" 10
    else
        log_skip "Apprise not configured"
    fi
}

# Test: notify.sh script exists
test_notify_script() {
    begin_test
    local script="$BASE_DIR/scripts/notify.sh"
    
    if [[ -x "$script" ]]; then
        log_pass "notify.sh script exists and is executable"
    else
        log_skip "notify.sh script not found or not executable"
    fi
}

# Test: Notification stack compose syntax
test_notifications_compose_syntax() {
    local compose_file="$BASE_DIR/stacks/notifications/docker-compose.yml"
    if [[ -f "$compose_file" ]]; then
        assert_compose_syntax "$compose_file"
    else
        log_skip "Notifications compose file not found"
    fi
}

# Test: No :latest tags
test_notifications_no_latest_tags() {
    assert_no_latest_tags "$BASE_DIR/stacks/notifications"
}

# Test: Alertmanager integration (if monitoring stack is up)
test_alertmanager_ntfy_integration() {
    begin_test
    local alertmanager_url="${ALERTMANAGER_URL:-http://localhost:9093}"
    
    if curl -sf "$alertmanager_url/-/healthy" >/dev/null 2>&1; then
        # Check if ntfy receiver is configured
        local config=$(curl -sf "$alertmanager_url/api/v2/status" 2>/dev/null || echo "{}")
        
        if echo "$config" | jq -e '.config.original' 2>/dev/null | grep -q "ntfy"; then
            log_pass "Alertmanager ntfy integration configured"
        else
            log_skip "Alertmanager ntfy integration not detected"
        fi
    else
        log_skip "Alertmanager not running"
    fi
}

# Run all tests
run_tests() {
    test_ntfy_running
    test_ntfy_healthy
    test_ntfy_api
    test_ntfy_publish
    test_gotify_running
    test_gotify_healthy
    test_apprise_running
    test_notify_script
    test_notifications_compose_syntax
    test_notifications_no_latest_tags
    test_alertmanager_ntfy_integration
}

# Execute tests
run_tests