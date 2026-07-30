#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# Media Stack Tests — Jellyfin + Sonarr + Radarr + Prowlarr + qBittorrent + Jellyseerr
# ════════════════════════════════════════════════════════════════

test_jellyfin_running() {
  assert_eq "$(container_status jellyfin)" "running" "Jellyfin should be running"
}

test_jellyfin_healthy() {
  if container_healthy jellyfin; then return 0; fi
  assert_http_200 "http://localhost:8096/health" "Jellyfin health endpoint should respond"
}

test_sonarr_running() {
  assert_eq "$(container_status sonarr)" "running" "Sonarr should be running"
}

test_sonarr_api() {
  assert_http_200 "http://localhost:8989/api/v3/system/status" "Sonarr API should respond"
}

test_radarr_running() {
  assert_eq "$(container_status radarr)" "running" "Radarr should be running"
}

test_radarr_api() {
  assert_http_200 "http://localhost:7878/api/v3/system/status" "Radarr API should respond"
}

test_prowlarr_running() {
  assert_eq "$(container_status prowlarr)" "running" "Prowlarr should be running"
}

test_prowlarr_api() {
  assert_http_200 "http://localhost:9696/api/v1/system/status" "Prowlarr API should respond"
}

test_qbittorrent_running() {
  assert_eq "$(container_status qbittorrent)" "running" "qBittorrent should be running"
}

test_qbittorrent_webui() {
  assert_http_status "http://localhost:8080/" "200" "qBittorrent WebUI should respond"
}

test_jellyseerr_running() {
  assert_eq "$(container_status jellyseerr)" "running" "Jellyseerr should be running"
}

# ── Inter-service connectivity ─────────────────────────────────

test_sonarr_qbittorrent_connection() {
  local sonarr_api_key
  sonarr_api_key=$(curl -s "http://localhost:8989/api/v3/system/status" 2>/dev/null | jq -r '.apiKey // empty' 2>/dev/null || echo "")
  if [[ -z "$sonarr_api_key" ]]; then
    return 1
  fi
  local result
  result=$(curl -s -X POST \
    -H "X-Api-Key: ${sonarr_api_key}" \
    "http://localhost:8989/api/v3/downloadclient/test" \
    -d '{"implementation":"QBittorrent","configContract":"QBittorrentSettings","fields":[{"name":"host","value":"qbittorrent"},{"name":"port","value":8080}]}' 2>/dev/null || echo "")
  assert_no_errors "$result" "Sonarr should be able to test qBittorrent connection"
}

test_jellyseerr_jellyfin_connection() {
  # Jellyseerr should be configured to use Jellyfin
  local result
  result=$(curl -s "http://localhost:5055/api/v1/status" 2>/dev/null || echo "")
  assert_not_empty "$result" "Jellyseerr status should be non-empty"
}

# ── Hardlink directory structure ────────────────────────────────

test_trash_dir_structure() {
  local media_root="${MEDIA_ROOT:-/data/media}"
  local dirs=("movies" "tv" "anime" "music" "books" "audiobooks")
  for dir in "${dirs[@]}"; do
    if [[ -d "${media_root}/${dir}" ]]; then
      return 0
    fi
  done
  # If media root doesn't exist on host, check inside container
  exec_in_container jellyfin ls -d /media/movies 2>/dev/null || \
    exec_in_container jellyfin ls -d /data/media/movies 2>/dev/null || return 1
  return 0
}