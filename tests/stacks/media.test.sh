#!/bin/bash
# media.test.sh - Media Stack 测试
# 测试 Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, Jellyseerr

set -u

# Jellyfin 测试
test_jellyfin_running() {
    assert_container_running "jellyfin"
}

test_jellyfin_http() {
    assert_http_200 "http://localhost:8096/health"
}

test_jellyfin_api() {
    assert_http_response "http://localhost:8096/System/Info/Public" "Version" "Jellyfin API"
}

# Sonarr 测试
test_sonarr_running() {
    assert_container_running "sonarr"
}

test_sonarr_api() {
    assert_http_response "http://localhost:8989/api/v3/system/status" "version" "Sonarr API v3"
}

# Radarr 测试
test_radarr_running() {
    assert_container_running "radarr"
}

test_radarr_api() {
    assert_http_response "http://localhost:7878/api/v3/system/status" "version" "Radarr API v3"
}

# qBittorrent 测试
test_qbittorrent_running() {
    assert_container_running "qbittorrent"
}

test_qbittorrent_http() {
    assert_http_200 "http://localhost:8080/api/v2/app/version"
}

# Prowlarr 测试
test_prowlarr_running() {
    assert_container_running "prowlarr"
}

test_prowlarr_api() {
    assert_http_response "http://localhost:9696/api/v1/system/status" "version" "Prowlarr API v1"
}

# Jellyseerr 测试
test_jellyseerr_running() {
    assert_container_running "jellyseerr"
}

test_jellyseerr_http() {
    assert_http_200 "http://localhost:5055/api/v1/status"
}
