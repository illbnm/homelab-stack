#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Media Stack Tests
# Services: Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent
# =============================================================================

COMPOSE_FILE="$BASE_DIR/stacks/media/docker-compose.yml"

# ===========================================================================
# Level 1 — Configuration Integrity
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "Media — Configuration"

  assert_compose_valid "$COMPOSE_FILE"
fi

# ===========================================================================
# Level 1 — Container Health
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -le 1 ]]; then
  test_group "Media — Container Health"

  assert_container_running "jellyfin"
  assert_container_healthy "jellyfin"
  assert_container_not_restarting "jellyfin"

  assert_container_running "sonarr"
  assert_container_healthy "sonarr"
  assert_container_not_restarting "sonarr"

  assert_container_running "radarr"
  assert_container_healthy "radarr"
  assert_container_not_restarting "radarr"

  assert_container_running "prowlarr"
  assert_container_healthy "prowlarr"
  assert_container_not_restarting "prowlarr"

  assert_container_running "qbittorrent"
  assert_container_healthy "qbittorrent"
  assert_container_not_restarting "qbittorrent"
fi

# ===========================================================================
# Level 2 — HTTP Endpoints
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 2 ]]; then
  test_group "Media — HTTP Endpoints"

  assert_http_200 "http://localhost:8096/health" \
    "Jellyfin /health"

  assert_http_ok "http://localhost:8989/ping" \
    "Sonarr /ping"

  assert_http_ok "http://localhost:7878/ping" \
    "Radarr /ping"

  assert_http_ok "http://localhost:9696/ping" \
    "Prowlarr /ping"

  assert_http_ok "http://localhost:8080" \
    "qBittorrent web UI"
fi

# ===========================================================================
# Level 3 — Service Interconnection
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 3 ]]; then
  test_group "Media — Interconnection"

  assert_container_in_network "jellyfin" "proxy"
  assert_container_in_network "sonarr" "proxy"
  assert_container_in_network "radarr" "proxy"

  # Sonarr → qBittorrent connectivity via internal network
  if is_container_running "sonarr" && is_container_running "qbittorrent"; then
    assert_docker_exec "sonarr" \
      "Sonarr can reach qBittorrent" \
      curl -sf --connect-timeout 5 "http://qbittorrent:8080"
  else
    skip_test "Sonarr can reach qBittorrent" "sonarr or qbittorrent not running"
  fi

  # Radarr → qBittorrent connectivity
  if is_container_running "radarr" && is_container_running "qbittorrent"; then
    assert_docker_exec "radarr" \
      "Radarr can reach qBittorrent" \
      curl -sf --connect-timeout 5 "http://qbittorrent:8080"
  else
    skip_test "Radarr can reach qBittorrent" "radarr or qbittorrent not running"
  fi

  # Prowlarr → Sonarr connectivity
  if is_container_running "prowlarr" && is_container_running "sonarr"; then
    assert_docker_exec "prowlarr" \
      "Prowlarr can reach Sonarr" \
      curl -sf --connect-timeout 5 "http://sonarr:8989/ping"
  else
    skip_test "Prowlarr can reach Sonarr" "prowlarr or sonarr not running"
  fi
fi
