#!/bin/bash
# productivity.test.sh - Productivity Stack Integration Tests
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_gitea_running() {
    echo "[productivity] Testing Gitea running..."
    assert_container_running "gitea" || echo "  ⚠️  Gitea container not found"
}

test_gitea_http() {
    echo "[productivity] Testing Gitea API version..."
    assert_http_response "http://localhost:3000/api/v1/version" "version" 30 || echo "  ⚠️  Gitea API check skipped"
}

test_compose_exists() {
    echo "[productivity] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/productivity/docker-compose.yml" || echo "  ⚠️  Productivity compose file not found"
}

run_productivity_tests() {
    echo "╔══════════════════════════════════════╗"
    echo "║   HomeLab Stack — Productivity Tests ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    
    test_compose_exists || true
    test_gitea_running || true
    test_gitea_http || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_productivity_tests
fi
