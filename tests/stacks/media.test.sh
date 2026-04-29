#!/usr/bin/env bash
assert_suite "media"

test_jellyfin_running() {
    assert_container_running jellyfin
}

test_jellyfin_healthy() {
    assert_container_healthy jellyfin 60
}

test_jellyfin_http() {
    assert_http_200 "http://localhost:8096/health" 10
}

test_sonarr_running() {
    assert_container_running sonarr
}

test_sonarr_api() {
    assert_http_response "http://localhost:8989/api/v3/system/status?apikey=${SONARR_API_KEY:-test}" '"version"'
}

test_radarr_running() {
    assert_container_running radarr
}

test_prowlarr_running() {
    assert_container_running prowlarr
}

test_qbittorrent_running() {
    assert_container_running qbittorrent
}

test_qbittorrent_http() {
    assert_http_200 "http://localhost:8080" 10
}

test_jellyseerr_running() {
    assert_container_running jellyseerr
}

test_jellyfin_running
test_jellyfin_healthy
test_jellyfin_http
test_sonarr_running
test_sonarr_api
test_radarr_running
test_prowlarr_running
test_qbittorrent_running
test_qbittorrent_http
test_jellyseerr_running