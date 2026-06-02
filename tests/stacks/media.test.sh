#!/usr/bin/env bash
# =============================================================================
# Media Stack Tests
# =============================================================================

test_jellyfin_running() {
  assert_container_running "jellyfin"
}

test_jellyfin_http() {
  assert_http_200 "http://localhost:8096/health" 10
}

test_sonarr_running() {
  assert_container_running "sonarr"
}

test_sonarr_http() {
  assert_http_200 "http://localhost:8989/ping" 10
}

test_radarr_running() {
  assert_container_running "radarr"
}

test_radarr_http() {
  assert_http_200 "http://localhost:7878/ping" 10
}

test_qbittorrent_running() {
  assert_container_running "qbittorrent"
}

test_qbittorrent_http() {
  assert_http_200 "http://localhost:8080" 10
}

run_test_with_timing "media" test_jellyfin_running "Jellyfin running"
run_test_with_timing "media" test_jellyfin_http "Jellyfin /health 200"
run_test_with_timing "media" test_sonarr_running "Sonarr running"
run_test_with_timing "media" test_sonarr_http "Sonarr /ping 200"
run_test_with_timing "media" test_radarr_running "Radarr running"
run_test_with_timing "media" test_radarr_http "Radarr /ping 200"
run_test_with_timing "media" test_qbittorrent_running "qBittorrent running"
run_test_with_timing "media" test_qbittorrent_http "qBittorrent HTTP 200"
