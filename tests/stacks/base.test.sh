#!/bin/bash
# base.test.sh - Base Stack 集成测试
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_traefik_running() {
    echo "[base] Testing Traefik running..."
    assert_container_running "traefik"
}

test_traefik_healthy() {
    echo "[base] Testing Traefik healthy..."
    assert_container_healthy "traefik" 60
}

test_portainer_running() {
    echo "[base] Testing Portainer running..."
    assert_container_running "portainer"
}

test_portainer_http() {
    echo "[base] Testing Portainer HTTP..."
    assert_http_200 "http://localhost:9000" 30
}

test_watchtower_running() {
    echo "[base] Testing Watchtower running..."
    assert_container_running "watchtower"
}

test_compose_exists() {
    echo "[base] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/base/docker-compose.yml"
}

run_base_tests() {
    echo "╔══════════════════════════════════════╗"
    echo "║   HomeLab Stack — Base Tests         ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    
    test_traefik_running || true
    test_traefik_healthy || true
    test_portainer_running || true
    test_portainer_http || true
    test_watchtower_running || true
    test_compose_exists || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_base_tests
fi
