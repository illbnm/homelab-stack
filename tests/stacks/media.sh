#!/usr/bin/env bash
# Media stack tests
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

test_jellyfin_running() {
  assert_container_running "jellyfin"
  assert_container_healthy "jellyfin"
  assert_http_200 "http://localhost:8096/health"
}

test_sonarr_running() {
  assert_container_running "sonarr"
  assert_http_200 "http://localhost:8989"
}

test_radarr_running() {
  assert_container_running "radarr"
  assert_http_200 "http://localhost:7878"
}

test_prowlarr_running() {
  assert_container_running "prowlarr"
  assert_http_200 "http://localhost:9696"
}

test_qbittorrent_running() {
  assert_container_running "qbittorrent"
}

test_jellyseerr_running() {
  assert_container_running "jellyseerr"
  assert_http_200 "http://localhost:5055"
}

run_test test_jellyfin_running
run_test test_sonarr_running
run_test test_radarr_running
run_test test_prowlarr_running
run_test test_qbittorrent_running
run_test test_jellyseerr_running
