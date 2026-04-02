#!/usr/bin/env bash
# Base Stack Tests - HomeLab Stack Integration Tests

set -euo pipefail

# 导入依赖
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

# 测试套件名称
STACK_NAME="base"

# Traefik 测试
test_traefik_running() {
    assert_container_running "traefik" "Traefik container should be running"
}

test_traefik_healthy() {
    assert_container_healthy "traefik" 60 "Traefik container should be healthy"
}

test_traefik_api() {
    assert_http_200 "http://localhost:8080/api/version" 30 "Traefik API should be accessible"
}

test_traefik_dashboard() {
    assert_http_200 "http://localhost:8080/dashboard/" 30 "Traefik dashboard should be accessible"
}

# Portainer 测试
test_portainer_running() {
    assert_container_running "portainer" "Portainer container should be running"
}

test_portainer_healthy() {
    assert_container_healthy "portainer" 60 "Portainer container should be healthy"
}

test_portainer_api() {
    assert_http_200 "http://localhost:9000/api/status" 30 "Portainer API should be accessible"
}

# Watchtower 测试
test_watchtower_running() {
    assert_container_running "watchtower" "Watchtower container should be running"
}

# Dozzle 测试
test_dozzle_running() {
    if container_exists "dozzle"; then
        assert_container_running "dozzle" "Dozzle container should be running"
    else
        echo -e "${YELLOW}⏭️  SKIP${NC}: Dozzle not configured"
        ((TESTS_SKIPPED++))
    fi
}

# 配置完整性测试
test_compose_syntax() {
    echo "Testing compose file syntax..."
    docker compose -f "stacks/$STACK_NAME/docker-compose.yml" config --quiet 2>&1
    assert_exit_code $? "Base stack compose file syntax is valid"
}

test_no_latest_tags() {
    assert_no_latest_images "stacks/$STACK_NAME" "Base stack should not use :latest image tags"
}

test_env_file_exists() {
    if [[ -f ".env" ]]; then
        echo -e "${GREEN}✅ PASS${NC}: .env file exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}: .env file missing"
        ((TESTS_FAILED++))
    fi
}

# 主测试运行器
run_base_tests() {
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║     Testing Stack: Base              ║"
    echo "╚══════════════════════════════════════╝"
    echo ""

    local start_time
    start_time=$(date +%s)

    # 运行所有测试
    test_compose_syntax || true
    test_no_latest_tags || true
    test_env_file_exists || true

    test_traefik_running || true
    test_traefik_healthy || true
    test_traefik_api || true
    test_traefik_dashboard || true

    test_portainer_running || true
    test_portainer_healthy || true
    test_portainer_api || true

    test_watchtower_running || true
    test_dozzle_running || true

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    echo "──────────────────────────────────────"
    echo "Base Stack Tests Complete"
    echo "Passed: $TESTS_PASSED | Failed: $TESTS_FAILED | Skipped: $TESTS_SKIPPED"
    echo "Duration: ${duration}s"
    echo "──────────────────────────────────────"
}

# 如果直接运行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_base_tests
fi
