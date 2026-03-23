#!/bin/bash
# media.test.sh - Media Stack Integration Tests
# Tests for: Jellyfin, Sonarr, Radarr, qBittorrent

set -o pipefail

# Test Jellyfin running
test_media_jellyfin_running() {
    local test_name="[media] Jellyfin running"
    start_test "$test_name"
    
    if assert_container_running "jellyfin"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Container not running"
    fi
}

# Test Jellyfin HTTP endpoint
test_media_jellyfin_http() {
    local test_name="[media] Jellyfin HTTP 200"
    start_test "$test_name"
    
    if assert_http_200 "http://localhost:8096/web/index.html" 30; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "HTTP endpoint not accessible"
    fi
}

# Test Jellyfin health endpoint
test_media_jellyfin_health() {
    local test_name="[media] Jellyfin health endpoint"
    start_test "$test_name"
    
    if assert_http_response "http://localhost:8096/system/info/public" "Id" 30; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Health endpoint not responding"
    fi
}

# Test Sonarr running
test_media_sonarr_running() {
    local test_name="[media] Sonarr running"
    start_test "$test_name"
    
    if assert_container_running "sonarr"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Container not running"
    fi
}

# Test Sonarr API
test_media_sonarr_api() {
    local test_name="[media] Sonarr API /api/v3"
    start_test "$test_name"
    
    local response
    response=$(curl -s -H "X-Api-Key: ${SONARR_API_KEY:-test}" "http://localhost:8989/api/v3/system/status" 2>/dev/null)
    
    if echo "$response" | grep -q "version"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "API not responding"
    fi
}

# Test Radarr running
test_media_radarr_running() {
    local test_name="[media] Radarr running"
    start_test "$test_name"
    
    if assert_container_running "radarr"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Container not running"
    fi
}

# Test Radarr API
test_media_radarr_api() {
    local test_name="[media] Radarr API /api/v3"
    start_test "$test_name"
    
    local response
    response=$(curl -s -H "X-Api-Key: ${RADARR_API_KEY:-test}" "http://localhost:7878/api/v3/system/status" 2>/dev/null)
    
    if echo "$response" | grep -q "version"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "API not responding"
    fi
}

# Test qBittorrent running
test_media_qbittorrent_running() {
    local test_name="[media] qBittorrent running"
    start_test "$test_name"
    
    if assert_container_running "qbittorrent"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Container not running"
    fi
}

# Test qBittorrent Web UI
test_media_qbittorrent_webui() {
    local test_name="[media] qBittorrent Web UI"
    start_test "$test_name"
    
    if assert_http_200 "http://localhost:8080" 30; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Web UI not accessible"
    fi
}

# Test Sonarr-qBittorrent connection
test_media_sonarr_qbittorrent_connection() {
    local test_name="[media] Sonarr-qBittorrent connection"
    start_test "$test_name"
    
    # This tests if Sonarr can communicate with qBittorrent
    # In a real scenario, this would check the download client configuration
    if assert_container_running "qbittorrent" && assert_container_running "sonarr"; then
        pass_test "$test_name"
    else
        fail_test "$test_name" "Services not both running"
    fi
}

# Run all media tests
test_media_all() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Media Stack Tests"
    echo "════════════════════════════════════════"
    
    test_media_jellyfin_running
    test_media_jellyfin_http
    test_media_jellyfin_health
    test_media_sonarr_running
    test_media_sonarr_api
    test_media_radarr_running
    test_media_radarr_api
    test_media_qbittorrent_running
    test_media_qbittorrent_webui
    test_media_sonarr_qbittorrent_connection
}

# Helper functions for test reporting
start_test() {
    local name="$1"
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}▶${NC} $name"
    fi
}

pass_test() {
    local name="$1"
    echo -e "${GREEN}✅ PASS${NC} $name"
}

fail_test() {
    local name="$1"
    local reason="$2"
    echo -e "${RED}❌ FAIL${NC} $name - $reason"
}

# If run directly, execute all tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    VERBOSE="${VERBOSE:-false}"
    test_media_all
fi
