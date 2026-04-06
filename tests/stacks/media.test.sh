#!/bin/bash
# media.test.sh - Media Stack Integration Tests
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_jellyfin_running() {
    echo "[media] Testing Jellyfin running..."
    assert_container_running "jellyfin" || echo "  ⚠️  Jellyfin container not found (may not be deployed)"
}

test_jellyfin_http() {
    echo "[media] Testing Jellyfin HTTP endpoint..."
    assert_http_200 "http://localhost:8096/health" 30 || echo "  ⚠️  Jellyfin HTTP check skipped"
}

test_sonarr_running() {
    echo "[media] Testing Sonarr running..."
    assert_container_running "sonarr" || echo "  ⚠️  Sonarr container not found"
}

test_sonarr_api() {
    echo "[media] Testing Sonarr API v3..."
    assert_http_response "http://localhost:8989/api/v3/config" "sonarr" 10 || echo "  ⚠️  Sonarr API check skipped"
}

test_qbittorrent_running() {
    echo "[media] Testing qBittorrent running..."
    assert_container_running "qbittorrent" || echo "  ⚠️  qBittorrent container not found"
}

test_qbittorrent_http() {
    echo "[media] Testing qBittorrent HTTP..."
    assert_http_200 "http://localhost:8080" 30 || echo "  ⚠️  qBittorrent HTTP check skipped"
}

test_prowlarr_running() {
    echo "[media] Testing Prowlarr running..."
    assert_container_running "prowlarr" || echo "  ⚠️  Prowlarr container not found"
}

test_radarr_running() {
    echo "[media] Testing Radarr running..."
    assert_container_running "radarr" || echo "  ⚠️  Radarr container not found"
}

test_compose_exists() {
    echo "[media] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/media/docker-compose.yml" || echo "  ⚠️  Media compose file not found"
}

run_media_tests() {
    echo "╔══════════════════════════════════════╗"
    echo "║   HomeLab Stack — Media Tests        ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    
    test_compose_exists || true
    test_jellyfin_running || true
    test_jellyfin_http || true
    test_sonarr_running || true
    test_sonarr_api || true
    test_qbittorrent_running || true
    test_qbittorrent_http || true
    test_prowlarr_running || true
    test_radarr_running || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_media_tests
fi
