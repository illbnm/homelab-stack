#!/usr/bin/env bash
# ==============================================================================
# Media Stack Tests
# Tests for Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, Jellyseerr
# ==============================================================================

# Test: Jellyfin container is running
test_jellyfin_running() {
    assert_container_running "jellyfin"
}

# Test: Jellyfin is healthy
test_jellyfin_healthy() {
    assert_container_healthy "jellyfin" 60
}

# Test: Jellyfin health endpoint
test_jellyfin_health() {
    assert_http_200 "http://localhost:8096/health" 10
}

# Test: Jellyfin API version
test_jellyfin_api() {
    assert_http_200 "http://localhost:8096/System/Info/Public" 10
}

# Test: Sonarr container is running
test_sonarr_running() {
    assert_container_running "sonarr"
}

# Test: Sonarr is healthy
test_sonarr_healthy() {
    assert_container_healthy "sonarr" 60
}

# Test: Sonarr API
test_sonarr_api() {
    local api_key="${SONARR_API_KEY:-}"
    if [[ -n "$api_key" ]]; then
        assert_http_200 "http://localhost:8989/api/v3/system/status?apikey=$api_key" 10
    else
        assert_http_200 "http://localhost:8989/ping" 10
    fi
}

# Test: Radarr container is running
test_radarr_running() {
    assert_container_running "radarr"
}

# Test: Radarr is healthy
test_radarr_healthy() {
    assert_container_healthy "radarr" 60
}

# Test: Radarr API
test_radarr_api() {
    local api_key="${RADARR_API_KEY:-}"
    if [[ -n "$api_key" ]]; then
        assert_http_200 "http://localhost:7878/api/v3/system/status?apikey=$api_key" 10
    else
        assert_http_200 "http://localhost:7878/ping" 10
    fi
}

# Test: Prowlarr container is running
test_prowlarr_running() {
    assert_container_running "prowlarr"
}

# Test: Prowlarr is healthy
test_prowlarr_healthy() {
    assert_container_healthy "prowlarr" 60
}

# Test: Prowlarr API
test_prowlarr_api() {
    assert_http_200 "http://localhost:9696/ping" 10
}

# Test: qBittorrent container is running
test_qbittorrent_running() {
    assert_container_running "qbittorrent"
}

# Test: qBittorrent is healthy
test_qbittorrent_healthy() {
    assert_container_healthy "qbittorrent" 60
}

# Test: qBittorrent WebUI
test_qbittorrent_webui() {
    assert_http_200 "http://localhost:8080" 10 || \
    assert_http_code "http://localhost:8080" 401 10  # May require auth
}

# Test: Jellyseerr container (if configured)
test_jellyseerr_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "jellyseerr"; then
        assert_container_running "jellyseerr"
        assert_http_200 "http://localhost:5055/api/v1/status" 10
    else
        log_skip "Jellyseerr not configured"
    fi
}

# Test: Media compose syntax
test_media_compose_syntax() {
    local compose_file="$BASE_DIR/stacks/media/docker-compose.yml"
    if [[ -f "$compose_file" ]]; then
        assert_compose_syntax "$compose_file"
    else
        log_skip "Media compose file not found"
    fi
}

# Test: No :latest tags
test_media_no_latest_tags() {
    assert_no_latest_tags "$BASE_DIR/stacks/media"
}

# Test: Media directories exist
test_media_directories() {
    begin_test
    local dirs=("config" "downloads" "movies" "tv")
    local all_exist=true
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$BASE_DIR/data/$dir" ]] && [[ ! -d "/mnt/$dir" ]]; then
            all_exist=false
            break
        fi
    done
    
    if [[ "$all_exist" == true ]]; then
        log_pass "Media directories configured"
    else
        log_skip "Some media directories not configured"
    fi
}

# Run all tests
run_tests() {
    test_jellyfin_running
    test_jellyfin_healthy
    test_jellyfin_health
    test_jellyfin_api
    test_sonarr_running
    test_sonarr_healthy
    test_sonarr_api
    test_radarr_running
    test_radarr_healthy
    test_radarr_api
    test_prowlarr_running
    test_prowlarr_healthy
    test_prowlarr_api
    test_qbittorrent_running
    test_qbittorrent_healthy
    test_qbittorrent_webui
    test_jellyseerr_running
    test_media_compose_syntax
    test_media_no_latest_tags
    test_media_directories
}

# Execute tests
run_tests