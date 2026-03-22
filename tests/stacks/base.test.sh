#!/bin/bash
# base.test.sh - Base Stack Integration Tests
# 测试基础设施组件：Traefik, Portainer, Watchtower

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

# Base Stack 测试
test_base_traefik_running() {
    local start_time=$(date +%s)
    assert_container_running "traefik"
    local duration=$(($(date +%s) - start_time))
    log_test "base" "Traefik running" "PASS" "$duration"
}

test_base_traefik_healthy() {
    local start_time=$(date +%s)
    assert_container_healthy "traefik" 60
    local duration=$(($(date +%s) - start_time))
    log_test "base" "Traefik healthy" "PASS" "$duration"
}

test_base_traefik_api() {
    local start_time=$(date +%s)
    assert_http_200 "http://localhost:8080/api/version" 30
    local duration=$(($(date +%s) - start_time))
    log_test "base" "Traefik API /api/version" "PASS" "$duration"
}

test_base_portainer_running() {
    local start_time=$(date +%s)
    assert_container_running "portainer"
    local duration=$(($(date +%s) - start_time))
    log_test "base" "Portainer running" "PASS" "$duration"
}

test_base_portainer_http() {
    local start_time=$(date +%s)
    assert_http_200 "http://localhost:9000" 30
    local duration=$(($(date +%s) - start_time))
    log_test "base" "Portainer HTTP 200" "PASS" "$duration"
}

test_base_portainer_api() {
    local start_time=$(date +%s)
    assert_http_response "http://localhost:9000/api/status" "healthy" 30
    local duration=$(($(date +%s) - start_time))
    log_test "base" "Portainer API /api/status" "PASS" "$duration"
}

test_base_watchtower_running() {
    local start_time=$(date +%s)
    assert_container_running "watchtower"
    local duration=$(($(date +%s) - start_time))
    log_test "base" "Watchtower running" "PASS" "$duration"
}

test_base_compose_syntax() {
    local start_time=$(date +%s)
    local compose_file="$SCRIPT_DIR/../../stacks/base/docker-compose.yml"
    
    if [[ ! -f "$compose_file" ]]; then
        log_test "base" "Compose file exists" "SKIP" "0" "File not found: $compose_file"
        return 0
    fi
    
    local output
    output=$(docker compose -f "$compose_file" config --quiet 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        local duration=$(($(date +%s) - start_time))
        log_test "base" "Compose syntax valid" "PASS" "$duration"
    else
        local duration=$(($(date +%s) - start_time))
        log_test "base" "Compose syntax valid" "FAIL" "$duration" "$output"
    fi
}

test_base_no_latest_tags() {
    local start_time=$(date +%s)
    local compose_file="$SCRIPT_DIR/../../stacks/base/docker-compose.yml"
    
    if [[ ! -f "$compose_file" ]]; then
        log_test "base" "No :latest tags" "SKIP" "0" "File not found"
        return 0
    fi
    
    local count
    count=$(grep -c ':latest' "$compose_file" 2>/dev/null || echo "0")
    
    if [[ "$count" -eq 0 ]]; then
        local duration=$(($(date +%s) - start_time))
        log_test "base" "No :latest tags" "PASS" "$duration"
    else
        local duration=$(($(date +%s) - start_time))
        log_test "base" "No :latest tags" "FAIL" "$duration" "Found $count :latest tags"
    fi
}

test_base_secrets_generated() {
    local start_time=$(date +%s)
    local env_file="$SCRIPT_DIR/../../.env"
    
    if [[ ! -f "$env_file" ]]; then
        log_test "base" ".env file exists" "SKIP" "0" ".env not generated yet"
        return 0
    fi
    
    # 检查关键变量是否存在
    if grep -q "TRAEFIK_DASHBOARD_PASSWORD" "$env_file" && \
       grep -q "PORTAINER_ADMIN_PASSWORD" "$env_file"; then
        local duration=$(($(date +%s) - start_time))
        log_test "base" "Secrets generated" "PASS" "$duration"
    else
        local duration=$(($(date +%s) - start_time))
        log_test "base" "Secrets generated" "FAIL" "$duration" "Missing required secrets"
    fi
}

# 运行所有 base 测试
test_base_all() {
    test_base_traefik_running
    test_base_traefik_healthy
    test_base_traefik_api
    test_base_portainer_running
    test_base_portainer_http
    test_base_portainer_api
    test_base_watchtower_running
    test_base_compose_syntax
    test_base_no_latest_tags
    test_base_secrets_generated
}

# 如果直接执行此文件，运行所有测试
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_report
    test_base_all
    
    stats=$(get_assert_stats)
    eval "$stats"
    finalize_report $ASSERT_PASS $ASSERT_FAIL $ASSERT_SKIP "$SCRIPT_DIR/../results"
fi
