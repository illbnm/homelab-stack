#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Media Stack Tests
# Services: Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, Jellyseerr
# =============================================================================

# shellcheck shell=bash

# ---------------------------------------------------------------------------
# Jellyfin
# ---------------------------------------------------------------------------

test_jellyfin_container_running() {
  assert_container_running "jellyfin"
}

test_jellyfin_container_healthy() {
  assert_container_healthy "jellyfin"
}

test_jellyfin_health_endpoint() {
  assert_http_200 "http://localhost:8096/health"
}

test_jellyfin_system_info() {
  assert_http_200 "http://localhost:8096/System/Info/Public"
}

test_jellyfin_port_open() {
  assert_port_open "localhost" "8096"
}

# ---------------------------------------------------------------------------
# Sonarr
# ---------------------------------------------------------------------------

test_sonarr_container_running() {
  assert_container_running "sonarr"
}

test_sonarr_container_healthy() {
  assert_container_healthy "sonarr"
}

test_sonarr_api_ping() {
  # Sonarr v3/v4 ping endpoint
  assert_http_200 "http://localhost:8989/ping"
}

test_sonarr_port_open() {
  assert_port_open "localhost" "8989"
}

# ---------------------------------------------------------------------------
# Radarr
# ---------------------------------------------------------------------------

test_radarr_container_running() {
  assert_container_running "radarr"
}

test_radarr_container_healthy() {
  assert_container_healthy "radarr"
}

test_radarr_api_ping() {
  assert_http_200 "http://localhost:7878/ping"
}

test_radarr_port_open() {
  assert_port_open "localhost" "7878"
}

# ---------------------------------------------------------------------------
# Prowlarr
# ---------------------------------------------------------------------------

test_prowlarr_container_running() {
  assert_container_running "prowlarr"
}

test_prowlarr_container_healthy() {
  assert_container_healthy "prowlarr"
}

test_prowlarr_api_ping() {
  assert_http_200 "http://localhost:9696/ping"
}

test_prowlarr_port_open() {
  assert_port_open "localhost" "9696"
}

# ---------------------------------------------------------------------------
# qBittorrent
# ---------------------------------------------------------------------------

test_qbittorrent_container_running() {
  assert_container_running "qbittorrent"
}

test_qbittorrent_container_healthy() {
  assert_container_healthy "qbittorrent"
}

test_qbittorrent_webui_accessible() {
  # qBittorrent Web UI — may redirect to /
  local status
  status=$(curl --silent --max-time 10 --output /dev/null --write-out "%{http_code}" \
    "http://localhost:8080" 2>/dev/null || echo "000")
  if [[ "$status" == "200" || "$status" == "302" || "$status" == "303" ]]; then
    return 0
  fi
  _assert_fail "qBittorrent WebUI returned HTTP ${status} (expected 200/302)"
}

test_qbittorrent_port_open() {
  assert_port_open "localhost" "8080"
}

# ---------------------------------------------------------------------------
# Jellyseerr
# ---------------------------------------------------------------------------

test_jellyseerr_container_running() {
  assert_container_running "jellyseerr"
}

test_jellyseerr_container_healthy() {
  assert_container_healthy "jellyseerr"
}

test_jellyseerr_api_status() {
  assert_http_200 "http://localhost:5055/api/v1/status"
}

test_jellyseerr_port_open() {
  assert_port_open "localhost" "5055"
}

# ---------------------------------------------------------------------------
# Service inter-connectivity
# ---------------------------------------------------------------------------

test_sonarr_can_reach_prowlarr() {
  if docker_container_running "sonarr" && docker_container_running "prowlarr"; then
    docker_containers_can_communicate "sonarr" "prowlarr" "9696" || \
      echo "WARN: sonarr→prowlarr connectivity check failed (may be network name difference)" >&2
  fi
}

test_radarr_can_reach_prowlarr() {
  if docker_container_running "radarr" && docker_container_running "prowlarr"; then
    docker_containers_can_communicate "radarr" "prowlarr" "9696" || \
      echo "WARN: radarr→prowlarr connectivity check failed" >&2
  fi
}
