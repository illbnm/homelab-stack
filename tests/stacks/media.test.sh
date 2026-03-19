#!/usr/bin/env bash
# =============================================================================
# media.test.sh — Media stack tests (jellyfin, sonarr, radarr, qbittorrent, prowlarr)
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1: Container health
# ---------------------------------------------------------------------------
test_suite "Media — Containers"

test_jellyfin_running() {
  assert_container_running "jellyfin"
  assert_container_healthy "jellyfin"
}

test_prowlarr_running() {
  assert_container_running "prowlarr"
  assert_container_healthy "prowlarr"
}

test_qbittorrent_running() {
  assert_container_running "qbittorrent"
  assert_container_healthy "qbittorrent"
}

test_radarr_running() {
  assert_container_running "radarr"
  assert_container_healthy "radarr"
}

test_sonarr_running() {
  assert_container_running "sonarr"
  assert_container_healthy "sonarr"
}

test_jellyfin_running
test_prowlarr_running
test_qbittorrent_running
test_radarr_running
test_sonarr_running

# ---------------------------------------------------------------------------
# Level 2: HTTP endpoints
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 2 ]]; then
  test_suite "Media — HTTP Endpoints"

  test_jellyfin_health() {
    assert_http_200 "http://localhost:8096/health" "Jellyfin /health"
  }

  test_prowlarr_ping() {
    assert_http_200 "http://localhost:9696/ping" "Prowlarr /ping"
  }

  test_qbittorrent_ui() {
    assert_http_200 "http://localhost:8080" "qBittorrent UI"
  }

  test_radarr_ping() {
    assert_http_200 "http://localhost:7878/ping" "Radarr /ping"
  }

  test_sonarr_ping() {
    assert_http_200 "http://localhost:8989/ping" "Sonarr /ping"
  }

  test_jellyfin_health
  test_prowlarr_ping
  test_qbittorrent_ui
  test_radarr_ping
  test_sonarr_ping
fi

# ---------------------------------------------------------------------------
# Level 3: Service interconnection
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 3 ]]; then
  test_suite "Media — Interconnection"

  test_sonarr_qbittorrent_connection() {
    if [[ -z "${SONARR_API_KEY:-}" ]]; then
      test_skip "Sonarr→qBittorrent connection" "SONARR_API_KEY not set"
      return
    fi
    local result
    result=$(curl -sf --connect-timeout 5 --max-time 10 \
      -X POST \
      -H "X-Api-Key: ${SONARR_API_KEY}" \
      -H "Content-Type: application/json" \
      "http://localhost:8989/api/v3/downloadclient/test" \
      -d '{"implementation":"QBittorrent","configContract":"QBittorrentSettings","fields":[{"name":"host","value":"qbittorrent"},{"name":"port","value":8080}]}' \
      2>/dev/null || echo '{"error":"request failed"}')
    assert_no_errors "$result" "Sonarr→qBittorrent connection test"
  }

  test_radarr_qbittorrent_connection() {
    if [[ -z "${RADARR_API_KEY:-}" ]]; then
      test_skip "Radarr→qBittorrent connection" "RADARR_API_KEY not set"
      return
    fi
    local result
    result=$(curl -sf --connect-timeout 5 --max-time 10 \
      -X POST \
      -H "X-Api-Key: ${RADARR_API_KEY}" \
      -H "Content-Type: application/json" \
      "http://localhost:7878/api/v3/downloadclient/test" \
      -d '{"implementation":"QBittorrent","configContract":"QBittorrentSettings","fields":[{"name":"host","value":"qbittorrent"},{"name":"port","value":8080}]}' \
      2>/dev/null || echo '{"error":"request failed"}')
    assert_no_errors "$result" "Radarr→qBittorrent connection test"
  }

  test_sonarr_qbittorrent_connection
  test_radarr_qbittorrent_connection
fi
