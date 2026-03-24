#!/usr/bin/env bash
# =============================================================================
# Media Stack Tests — Jellyfin + Sonarr + Radarr + Prowlarr + qBittorrent
# =============================================================================

# Container health
assert_container_running jellyfin
assert_container_healthy jellyfin 60
assert_container_running sonarr
assert_container_healthy sonarr 60
assert_container_running radarr
assert_container_healthy radarr 60
assert_container_running prowlarr
assert_container_healthy prowlarr 60
assert_container_running qbittorrent
assert_container_healthy qbittorrent 60

# HTTP endpoints
assert_http_200 "http://localhost:8096/health" 10
assert_http_200 "http://localhost:8989/api/v3/system/status" 10
assert_http_200 "http://localhost:7878/api/v3/system/status" 10
assert_http_200 "http://localhost:9696/ping" 10
assert_http_200 "http://localhost:8080" 10

# Jellyfin system info
test_start "Jellyfin system info"
jf_info=$(curl -sf "http://localhost:8096/System/Info/Public" 2>/dev/null || echo "")
if echo "$jf_info" | grep -qi "server"; then
  test_pass
else
  test_fail "Jellyfin system info not accessible"
fi

# Sonarr API
test_start "Sonarr API accessible"
sonarr_api=$(curl -sf "http://localhost:8989/api/v3/system/status" 2>/dev/null | jq -r '.version' 2>/dev/null || echo "")
if [[ -n "$sonarr_api" ]]; then
  test_pass
else
  test_fail "Sonarr API not returning version info"
fi

# Radarr API
test_start "Radarr API accessible"
radarr_api=$(curl -sf "http://localhost:7878/api/v3/system/status" 2>/dev/null | jq -r '.version' 2>/dev/null || echo "")
if [[ -n "$radarr_api" ]]; then
  test_pass
else
  test_fail "Radarr API not returning version info"
fi

# Prowlarr API
test_start "Prowlarr API accessible"
prowlarr_api=$(curl -sf "http://localhost:9696/api/v1/system/status" 2>/dev/null | jq -r '.version' 2>/dev/null || echo "")
if [[ -n "$prowlarr_api" ]]; then
  test_pass
else
  test_fail "Prowlarr API not returning version info"
fi

# Verify all media containers share the proxy network
test_start "Media containers on proxy network"
media_on_proxy=true
for c in jellyfin sonarr radarr prowlarr qbittorrent; do
  if ! docker inspect "$c" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null | grep -q proxy; then
    media_on_proxy=false
    break
  fi
done
if [[ "$media_on_proxy" == "true" ]]; then
  test_pass
else
  test_fail "Not all media containers on proxy network"
fi
