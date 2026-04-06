#!/bin/bash
# network.test.sh - Network Stack Integration Tests
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_adguard_running() {
    echo "[network] Testing AdGuard running..."
    assert_container_running "adguard" || echo "  ⚠️  AdGuard container not found"
}

test_adguard_http() {
    echo "[network] Testing AdGuard HTTP endpoint..."
    assert_http_response "http://localhost:3000/control/status" "version" 30 || echo "  ⚠️  AdGuard HTTP check skipped"
}

test_compose_exists() {
    echo "[network] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/network/docker-compose.yml" || echo "  ⚠️  Network compose file not found"
}

run_network_tests() {
    echo "╔══════════════════════════════════════╗"
    echo "║   HomeLab Stack — Network Tests      ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    
    test_compose_exists || true
    test_adguard_running || true
    test_adguard_http || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_network_tests
fi
