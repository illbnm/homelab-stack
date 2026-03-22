#!/bin/bash
# storage.test.sh - Storage Stack Integration Tests
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_nextcloud_running() {
    echo "[storage] Testing Nextcloud running..."
    assert_container_running "nextcloud" || echo "  ⚠️  Nextcloud container not found"
}

test_nextcloud_http() {
    echo "[storage] Testing Nextcloud HTTP endpoint..."
    assert_http_response "http://localhost:8080/status.php" "installed" 30 || echo "  ⚠️  Nextcloud HTTP check skipped"
}

test_samba_running() {
    echo "[storage] Testing Samba running..."
    assert_container_running "samba" || echo "  ⚠️  Samba container not found"
}

test_compose_exists() {
    echo "[storage] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/storage/docker-compose.yml" || echo "  ⚠️  Storage compose file not found"
}

run_storage_tests() {
    echo "╔══════════════════════════════════════╗"
    echo "║   HomeLab Stack — Storage Tests      ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    
    test_compose_exists || true
    test_nextcloud_running || true
    test_nextcloud_http || true
    test_samba_running || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_storage_tests
fi
