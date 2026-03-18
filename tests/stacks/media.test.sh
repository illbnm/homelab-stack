#!/usr/bin/env bash
# =============================================================================
# Media Stack Tests — Jellyfin + Jellyseerr + Sonarr + Radarr + Prowlarr + qBittorrent
# =============================================================================

# --- Level 1: Container Health ---

test_media_jellyfin_running() {
  assert_container_running "homelab-jellyfin"
}

test_media_jellyfin_healthy() {
  assert_container_healthy "homelab-jellyfin" 90
}

test_media_jellyseerr_running() {
  assert_container_running "homelab-jellyseerr"
}

test_media_sonarr_running() {
  assert_container_running "homelab-sonarr"
}

test_media_radarr_running() {
  assert_container_running "homelab-radarr"
}

test_media_prowlarr_running() {
  assert_container_running "homelab-prowlarr"
}

test_media_qbittorrent_running() {
  assert_container_running "homelab-qbittorrent"
}

# --- Level 1: Configuration ---

test_media_compose_syntax() {
  local output
  output=$(compose_config_valid "stacks/media/docker-compose.yml" 2>&1)
  _LAST_EXIT_CODE=$?
  assert_exit_code 0 "media compose syntax invalid: ${output}"
}

test_media_no_latest_tags() {
  assert_no_latest_images "stacks/media/"
}

# --- Level 2: HTTP Endpoints ---

test_media_jellyfin_health() {
  local ip
  ip=$(get_container_ip homelab-jellyfin)
  assert_http_200 "http://${ip}:8096/health" 30
}

test_media_jellyseerr_http() {
  local ip
  ip=$(get_container_ip homelab-jellyseerr)
  assert_http_200 "http://${ip}:5055" 30
}

test_media_sonarr_api() {
  local ip
  ip=$(get_container_ip homelab-sonarr)
  assert_http_200 "http://${ip}:8989/api/v3/system/status" 30
}

test_media_radarr_api() {
  local ip
  ip=$(get_container_ip homelab-radarr)
  assert_http_200 "http://${ip}:7878/api/v3/system/status" 30
}

test_media_prowlarr_http() {
  local ip
  ip=$(get_container_ip homelab-prowlarr)
  assert_http_200 "http://${ip}:9696" 30
}

test_media_qbittorrent_http() {
  local ip
  ip=$(get_container_ip homelab-qbittorrent)
  assert_http_200 "http://${ip}:8080" 30
}
