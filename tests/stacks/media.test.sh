#!/usr/bin/env bash
# =============================================================================
# Media Stack Tests — Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent
# =============================================================================

log_group "Media Stack"

# --- Level 1: Container health ---

MEDIA_CONTAINERS=(jellyfin sonarr radarr prowlarr qbittorrent)

for c in "${MEDIA_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_running "$c"
    assert_container_healthy "$c"
    assert_container_not_restarting "$c"
  else
    skip_test "Container '$c'" "not running"
  fi
done

# --- Level 2: HTTP endpoints ---
if [[ "${TEST_LEVEL:-99}" -ge 2 ]]; then

  test_jellyfin_http() {
    require_container "jellyfin" || return
    assert_http_200 "http://localhost:8096/health" "Jellyfin /health"
  }

  test_sonarr_http() {
    require_container "sonarr" || return
    assert_http_ok "http://localhost:8989/ping" "Sonarr /ping"
  }

  test_radarr_http() {
    require_container "radarr" || return
    assert_http_ok "http://localhost:7878/ping" "Radarr /ping"
  }

  test_prowlarr_http() {
    require_container "prowlarr" || return
    assert_http_ok "http://localhost:9696/ping" "Prowlarr /ping"
  }

  test_qbittorrent_http() {
    require_container "qbittorrent" || return
    assert_http_ok "http://localhost:8080" "qBittorrent Web UI"
  }

  test_jellyfin_http
  test_sonarr_http
  test_radarr_http
  test_prowlarr_http
  test_qbittorrent_http
fi

# --- Level 3: Service interconnection ---
if [[ "${TEST_LEVEL:-99}" -ge 3 ]]; then

  # Sonarr must be able to reach qBittorrent
  test_sonarr_qbittorrent_connection() {
    require_container "sonarr" || return
    require_container "qbittorrent" || return
    # Test via Sonarr's download client test endpoint
    local api_key
    api_key=$(docker_exec "sonarr" cat /config/config.xml 2>/dev/null | grep -oP '<ApiKey>\K[^<]+' || echo "")
    if [[ -z "$api_key" ]]; then
      skip_test "Sonarr → qBittorrent connection" "cannot read Sonarr API key"
      return
    fi
    local result
    result=$(curl -sf -X POST \
      -H "X-Api-Key: $api_key" \
      -H "Content-Type: application/json" \
      "http://localhost:8989/api/v3/downloadclient/test" \
      -d '{"implementation":"QBittorrent","configContract":"QBittorrentSettings","fields":[{"name":"host","value":"qbittorrent"},{"name":"port","value":8080}]}' 2>/dev/null)
    assert_no_errors "$result" "Sonarr → qBittorrent connection test"
  }

  # Radarr must be able to reach qBittorrent
  test_radarr_qbittorrent_connection() {
    require_container "radarr" || return
    require_container "qbittorrent" || return
    local api_key
    api_key=$(docker_exec "radarr" cat /config/config.xml 2>/dev/null | grep -oP '<ApiKey>\K[^<]+' || echo "")
    if [[ -z "$api_key" ]]; then
      skip_test "Radarr → qBittorrent connection" "cannot read Radarr API key"
      return
    fi
    local result
    result=$(curl -sf -X POST \
      -H "X-Api-Key: $api_key" \
      -H "Content-Type: application/json" \
      "http://localhost:7878/api/v3/downloadclient/test" \
      -d '{"implementation":"QBittorrent","configContract":"QBittorrentSettings","fields":[{"name":"host","value":"qbittorrent"},{"name":"port","value":8080}]}' 2>/dev/null)
    assert_no_errors "$result" "Radarr → qBittorrent connection test"
  }

  # All media containers on proxy network
  test_media_proxy_network() {
    for c in "${MEDIA_CONTAINERS[@]}"; do
      if is_container_running "$c"; then
        assert_container_on_network "$c" "proxy"
      fi
    done
  }

  test_sonarr_qbittorrent_connection
  test_radarr_qbittorrent_connection
  test_media_proxy_network
fi

# --- Image tags ---
for c in "${MEDIA_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_image_not_latest "$c"
  fi
done
