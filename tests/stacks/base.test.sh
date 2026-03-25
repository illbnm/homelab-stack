#!/bin/bash
# =============================================================================
# base.test.sh - Base stack tests
# =============================================================================

test_compose_syntax() {
    local start=$(date +%s)
    local result="PASS"
    local error=""
    
    if docker compose -f stacks/base/docker-compose.yml config --quiet 2>&1; then
        :
    else
        result="FAIL"
        error="docker-compose.yml syntax error"
    fi
    
    local end=$(date +%s)
    print_test_result "Compose syntax" "$result" $((end - start)) "$error"
}

test_no_latest_images() {
    local start=$(date +%s)
    local result="PASS"
    local error=""
    
    if assert_no_latest_images "stacks/base" 2>&1; then
        :
    else
        result="FAIL"
        error="Found :latest image tags"
    fi
    
    local end=$(date +%s)
    print_test_result "No :latest tags" "$result" $((end - start)) "$error"
}

test_traefik_running() {
    local start=$(date +%s)
    local result="PASS"
    local error=""
    
    if assert_container_running "traefik" 2>&1; then
        :
    else
        result="FAIL"
        error="Traefik not running"
    fi
    
    local end=$(date +%s)
    print_test_result "Traefik running" "$result" $((end - start)) "$error"
}

test_traefik_healthy() {
    local start=$(date +%s)
    local result="PASS"
    local error=""
    
    if assert_container_healthy "traefik" 60 2>&1; then
        :
    else
        result="FAIL"
        error="Traefik not healthy"
    fi
    
    local end=$(date +%s)
    print_test_result "Traefik healthy" "$result" $((end - start)) "$error"
}

test_portainer_running() {
    local start=$(date +%s)
    local result="PASS"
    local error=""
    
    if assert_container_running "portainer" 2>&1; then
        :
    else
        result="FAIL"
        error="Portainer not running"
    fi
    
    local end=$(date +%s)
    print_test_result "Portainer running" "$result" $((end - start)) "$error"
}

test_watchtower_running() {
    local start=$(date +%s)
    local result="PASS"
    local error=""
    
    if assert_container_running "watchtower" 2>&1; then
        :
    else
        result="FAIL"
        error="Watchtower not running"
    fi
    
    local end=$(date +%s)
    print_test_result "Watchtower running" "$result" $((end - start)) "$error"
}

# Run all tests
test_compose_syntax
test_no_latest_images
test_traefik_running
test_traefik_healthy
test_portainer_running
test_watchtower_running
