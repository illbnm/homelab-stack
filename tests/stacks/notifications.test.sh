#!/bin/bash
# notifications.test.sh - Notifications Stack 集成测试
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_apprise_running() {
    echo "[notifications] Testing Apprise running..."
    assert_container_running "apprise" || return 0  # Optional
}

test_apprise_http() {
    echo "[notifications] Testing Apprise HTTP..."
    assert_http_200 "http://localhost:8000/notify" 30 || return 0
}

test_gotify_running() {
    echo "[notifications] Testing Gotify running..."
    assert_container_running "gotify"
}

test_gotify_http() {
    echo "[notifications] Testing Gotify HTTP..."
    assert_http_200 "http://localhost:8084/health" 30
}

test_ntfy_running() {
    echo "[notifications] Testing ntfy running..."
    assert_container_running "ntfy" || return 0  # Optional
}

test_ntfy_http() {
    echo "[notifications] Testing ntfy HTTP..."
    assert_http_200 "http://localhost:8085/v1/health" 30 || return 0
}

test_compose_exists() {
    echo "[notifications] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/notifications/docker-compose.yml"
}

run_notifications_tests() {
    print_header "HomeLab Stack — Notifications Tests"
    
    test_compose_exists || true
    test_apprise_running || true
    test_apprise_http || true
    test_gotify_running || true
    test_gotify_http || true
    test_ntfy_running || true
    test_ntfy_http || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_notifications_tests
fi
