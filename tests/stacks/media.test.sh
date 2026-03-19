#!/usr/bin/env bash
# =============================================================================
# tests/stacks/media.test.sh — Media Stack (Jellyfin + Sonarr + Radarr + qBittorrent)
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
source "$SCRIPT_DIR/tests/lib/assert.sh"
source "$SCRIPT_DIR/tests/lib/docker.sh"

test_jellyfin_running() {
  assert_container_running "jellyfin"
}

test_jellyfin_healthy() {
  assert_container_healthy "jellyfin" 60
}

test_jellyfin_http() {
  assert_http_200 "http://localhost:8096/health" 10
}

test_jellyfin_api() {
  local code
  code=$(http_status "http://localhost:8096/System/Info" 10)
  assert_contains "200 401 403" "$code"
}

test_sonarr_running() {
  assert_container_running "sonarr"
}

test_sonarr_http() {
  local code
  code=$(http_status "http://localhost:8989/api/v3/system/status" 10)
  assert_contains "200 401" "$code"
}

test_radarr_running() {
  assert_container_running "radarr"
}

test_radarr_http() {
  local code
  code=$(http_status "http://localhost:7878/api/v3/system/status" 10)
  assert_contains "200 401" "$code"
}

test_qbittorrent_running() {
  assert_container_running "qbittorrent"
}

test_qbittorrent_http() {
  local code
  code=$(http_status "http://localhost:8080" 10)
  assert_contains "200 302" "$code"
}

test_media_compose_valid() {
  assert_compose_valid "$SCRIPT_DIR/stacks/media/docker-compose.yml"
}
