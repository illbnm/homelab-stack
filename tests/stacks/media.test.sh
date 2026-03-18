#!/usr/bin/env bash
# media.test.sh — Media Stack Tests (Jellyfin, Prowlarr, qBittorrent, Sonarr, Radarr)
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-stacks/media/docker-compose.yml}"

test_jellyfin_running() {
  test_start "Jellyfin running"
  assert_container_running "jellyfin"; test_end
}
test_jellyfin_healthy() {
  test_start "Jellyfin healthy"
  assert_container_healthy "jellyfin" 60; test_end
}
test_jellyfin_http() {
  test_start "Jellyfin /health"
  assert_http_200 "http://localhost:8096/health" 15; test_end
}
test_prowlarr_running() {
  test_start "Prowlarr running"
  assert_container_running "prowlarr"; test_end
}
test_prowlarr_healthy() {
  test_start "Prowlarr healthy"
  assert_container_healthy "prowlarr" 60; test_end
}
test_qbittorrent_running() {
  test_start "qBittorrent running"
  assert_container_running "qbittorrent"; test_end
}
test_qbittorrent_healthy() {
  test_start "qBittorrent healthy"
  assert_container_healthy "qbittorrent" 60; test_end
}
test_compose_syntax() {
  test_start "Media compose syntax valid"
  assert_exit_code 0 docker compose -f "$COMPOSE_FILE" config --quiet; test_end
}
