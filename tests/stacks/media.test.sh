#!/bin/bash
# media.test.sh - Media Stack 集成测试
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

test_jellyfin_running() {
    echo "[media] Testing Jellyfin running..."
    assert_container_running "jellyfin"
}

test_jellyfin_http() {
    echo "[media] Testing Jellyfin HTTP..."
    assert_http_200 "http://localhost:8096/health" 30
}

test_sonarr_running() {
    echo "[media] Testing Sonarr running..."
    assert_container_running "sonarr"
}

test_sonarr_http() {
    echo "[media] Testing Sonarr API /v3..."
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "http://localhost:8989/api/v3/system/status" 2>/dev/null)
    if [[ "$http_code" == "200" || "$http_code" == "401" ]]; then
        echo -e "${GREEN}✅ PASS${NC} (Auth required)"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} Sonarr API returned $http_code"
        return 1
    fi
}

test_radarr_running() {
    echo "[media] Testing Radarr running..."
    assert_container_running "radarr"
}

test_qbittorrent_running() {
    echo "[media] Testing qBittorrent running..."
    assert_container_running "qbittorrent"
}

test_qbittorrent_http() {
    echo "[media] Testing qBittorrent HTTP..."
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "http://localhost:8080/api/v2/app/version" 2>/dev/null)
    if [[ "$http_code" == "200" || "$http_code" == "403" ]]; then
        echo -e "${GREEN}✅ PASS${NC} (Auth required)"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} qBittorrent API returned $http_code"
        return 1
    fi
}

test_plex_running() {
    echo "[media] Testing Plex running..."
    assert_container_running "plex" || return 0  # Optional
}

test_compose_exists() {
    echo "[media] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/media/docker-compose.yml"
}

run_media_tests() {
    print_header "HomeLab Stack — Media Tests"
    
    test_compose_exists || true
    test_jellyfin_running || true
    test_jellyfin_http || true
    test_sonarr_running || true
    test_sonarr_http || true
    test_radarr_running || true
    test_qbittorrent_running || true
    test_qbittorrent_http || true
    test_plex_running || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_media_tests
fi
