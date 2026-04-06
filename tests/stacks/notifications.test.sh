#!/bin/bash
# notifications.test.sh - Notifications Stack Integration Tests
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_gotify_running() {
    echo "[notifications] Testing Gotify running..."
    assert_container_running "gotify" || echo "  ⚠️  Gotify container not found"
}

test_gotify_http() {
    echo "[notifications] Testing Gotify HTTP endpoint..."
    assert_http_200 "http://localhost:8070/health" 30 || echo "  ⚠️  Gotify HTTP check skipped"
}

test_ntfy_running() {
    echo "[notifications] Testing ntfy running..."
    assert_container_running "ntfy" || echo "  ⚠️  ntfy container not found"
}

test_compose_exists() {
    echo "[notifications] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/notifications/docker-compose.yml" || echo "  ⚠️  Notifications compose file not found"
}

run_notifications_tests() {
    echo "╔══════════════════════════════════════╗"
    echo "║   HomeLab Stack — Notifications Tests║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    
    test_compose_exists || true
    test_gotify_running || true
    test_gotify_http || true
    test_ntfy_running || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_notifications_tests
fi
