#!/bin/bash
# =============================================================================
# sso.test.sh - SSO stack tests
# =============================================================================

test_compose_syntax() {
    local start=$(date +%s)
    local result="PASS"
    docker compose -f stacks/sso/docker-compose.yml config --quiet 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "Compose syntax" "$result" $((end - start))
}

test_authentik_running() {
    local start=$(date +%s)
    local result="PASS"
    assert_container_running "authentik-server" 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "Authentik server running" "$result" $((end - start))
}

test_authentik_worker_running() {
    local start=$(date +%s)
    local result="PASS"
    assert_container_running "authentik-worker" 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "Authentik worker running" "$result" $((end - start))
}

# Run all tests
test_compose_syntax
test_authentik_running
test_authentik_worker_running
