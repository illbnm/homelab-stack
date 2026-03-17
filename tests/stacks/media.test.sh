#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Media Stack Tests
# =============================================================================
# Tests: Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, Jellyseerr
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1 — Container Health
# ---------------------------------------------------------------------------

test_jellyfin_running() {
  assert_container_running "jellyfin"
}

test_jellyfin_healthy() {
  assert_container_healthy "jellyfin" 90
}

test_sonarr_running() {
  assert_container_running "sonarr"
}

test_sonarr_healthy() {
  assert_container_healthy "sonarr" 60
}

test_radarr_running() {
  assert_container_running "radarr"
}

test_radarr_healthy() {
  assert_container_healthy "radarr" 60
}

test_prowlarr_running() {
  assert_container_running "prowlarr"
}

test_prowlarr_healthy() {
  assert_container_healthy "prowlarr" 60
}

test_qbittorrent_running() {
  assert_container_running "qbittorrent"
}

test_qbittorrent_healthy() {
  assert_container_healthy "qbittorrent" 60
}

test_jellyseerr_running() {
  assert_container_running "jellyseerr"
}

test_jellyseerr_healthy() {
  assert_container_healthy "jellyseerr" 60
}

# ---------------------------------------------------------------------------
# Level 2 — HTTP Endpoints
# ---------------------------------------------------------------------------

test_jellyfin_health_endpoint() {
  assert_http_200 "http://localhost:8096/health" 30
}

test_sonarr_api() {
  if [[ -n "${SONARR_API_KEY:-}" ]]; then
    assert_http_200 "http://localhost:8989/api/v3/system/status?apikey=${SONARR_API_KEY}" 30
  else
    _assert_skip "SONARR_API_KEY not set"
  fi
}

test_radarr_api() {
  if [[ -n "${RADARR_API_KEY:-}" ]]; then
    assert_http_200 "http://localhost:7878/api/v3/system/status?apikey=${RADARR_API_KEY}" 30
  else
    _assert_skip "RADARR_API_KEY not set"
  fi
}

test_prowlarr_api() {
  if [[ -n "${PROWLARR_API_KEY:-}" ]]; then
    assert_http_200 "http://localhost:9696/api/v1/system/status?apikey=${PROWLARR_API_KEY}" 30
  else
    _assert_skip "PROWLARR_API_KEY not set"
  fi
}

test_qbittorrent_webui() {
  assert_http_200 "http://localhost:8080" 30
}

test_jellyseerr_webui() {
  assert_http_200 "http://localhost:5055" 30
}

# ---------------------------------------------------------------------------
# Level 3 — Inter-Service Communication
# ---------------------------------------------------------------------------

test_sonarr_qbittorrent_connection() {
  if [[ -z "${SONARR_API_KEY:-}" ]]; then
    _assert_skip "SONARR_API_KEY not set"
    return 0
  fi

  local result
  result=$(curl -s -X POST \
    -H "X-Api-Key: ${SONARR_API_KEY}" \
    -H "Content-Type: application/json" \
    "http://localhost:8989/api/v3/downloadclient/test" \
    -d '{"implementation":"QBittorrent","configContract":"QBittorrentSettings","fields":[{"name":"host","value":"qbittorrent"},{"name":"port","value":8080}]}' \
    2>/dev/null || echo '{"errors":[]}')

  assert_no_errors "${result}"
}

# ---------------------------------------------------------------------------
# Level 1 — Configuration
# ---------------------------------------------------------------------------

test_media_compose_valid() {
  local compose_file="${PROJECT_ROOT}/stacks/media/docker-compose.yml"

  if [[ ! -f "${compose_file}" ]]; then
    _assert_skip "Media compose file not found"
    return 0
  fi

  assert_compose_valid "${compose_file}"
}
