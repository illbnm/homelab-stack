#!/bin/bash
# =============================================================================
# notifications.test.sh - Notifications stack tests
# =============================================================================

test_compose_syntax() {
    local start=$(date +%s)
    local result="PASS"
    
    docker compose -f stacks/notifications/docker-compose.yml config --quiet 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "Compose syntax" "$result" $((end - start))
}

test_ntfy_running() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_running "ntfy" 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "ntfy running" "$result" $((end - start))
}

test_ntfy_healthy() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_healthy "ntfy" 60 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "ntfy healthy" "$result" $((end - start))
}

test_gotify_running() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_running "gotify" 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "Gotify running" "$result" $((end - start))
}

test_notify_script_syntax() {
    local start=$(date +%s)
    local result="PASS"
    
    bash -n scripts/notify.sh 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "notify.sh syntax" "$result" $((end - start))
}

# Run all tests
test_compose_syntax
test_ntfy_running
test_ntfy_healthy
test_gotify_running
test_notify_script_syntax
