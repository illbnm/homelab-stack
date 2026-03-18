#!/usr/bin/env bash
# =============================================================================
# media.test.sh — Media stack tests
# Services: Jellyfin, Prowlarr, Sonarr, Radarr, qBittorrent
# =============================================================================

# --- Jellyfin ---

test_jellyfin_running() {
  assert_container_running "jellyfin"
}

test_jellyfin_healthy() {
  assert_container_healthy "jellyfin"
}

test_jellyfin_health_endpoint() {
  assert_http_200 "http://localhost:8096/health" 15
}

test_jellyfin_no_crash_loop() {
  assert_no_crash_loop "jellyfin" 3
}

test_jellyfin_in_proxy_network() {
  assert_container_in_network "jellyfin" "proxy"
}

# --- Prowlarr ---

test_prowlarr_running() {
  assert_container_running "prowlarr"
}

test_prowlarr_healthy() {
  assert_container_healthy "prowlarr"
}

test_prowlarr_ui() {
  assert_http_status "http://localhost:9696" 200 10
}

test_prowlarr_no_crash_loop() {
  assert_no_crash_loop "prowlarr" 3
}

# --- Sonarr ---

test_sonarr_running() {
  assert_container_running "sonarr"
}

test_sonarr_healthy() {
  assert_container_healthy "sonarr"
}

test_sonarr_api() {
  # Sonarr v3 API
  assert_http_status "http://localhost:8989" 200 10
}

test_sonarr_no_crash_loop() {
  assert_no_crash_loop "sonarr" 3
}

# --- Radarr ---

test_radarr_running() {
  assert_container_running "radarr"
}

test_radarr_healthy() {
  assert_container_healthy "radarr"
}

test_radarr_api() {
  assert_http_status "http://localhost:7878" 200 10
}

test_radarr_no_crash_loop() {
  assert_no_crash_loop "radarr" 3
}

# --- qBittorrent ---

test_qbittorrent_running() {
  assert_container_running "qbittorrent"
}

test_qbittorrent_healthy() {
  assert_container_healthy "qbittorrent"
}

test_qbittorrent_webui() {
  assert_http_status "http://localhost:8080" 200 10
}

test_qbittorrent_no_crash_loop() {
  assert_no_crash_loop "qbittorrent" 3
}
