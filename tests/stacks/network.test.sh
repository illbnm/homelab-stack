#!/bin/bash
# =============================================================================
# network.test.sh - Network stack tests
# =============================================================================

test_compose_syntax() {
    local start=$(date +%s)
    local result="PASS"
    docker compose -f stacks/network/docker-compose.yml config --quiet 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "Compose syntax" "$result" $((end - start))
}

test_adguard_running() {
    local start=$(date +%s)
    local result="PASS"
    assert_container_running "adguard" 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "AdGuard running" "$result" $((end - start))
}

# Run all tests
test_compose_syntax
test_adguard_running
