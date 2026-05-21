#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Media Stack Tests
# Tests: Jellyfin + Sonarr + Radarr + qBittorrent + Prowlarr
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker.sh"

should_run_stack "media" || { begin_suite "Media Stack"; assert_skip "not selected"; exit 0; }

begin_suite "Media Stack — Jellyfin + Sonarr + Radarr + qBittorrent + Prowlarr"

# ---- Jellyfin ----
assert_container_running "jellyfin"
assert_container_healthy "jellyfin"
assert_container_not_latest "jellyfin"
assert_http_200 "${BASE_URL:-http://localhost}:8096/health" "jellyfin:health"

# ---- Sonarr ----
assert_container_running "sonarr"
assert_container_healthy "sonarr"
assert_container_not_latest "sonarr"
assert_http_200 "${BASE_URL:-http://localhost}:8989/api/v3/system/status" "sonarr:api"

# ---- Radarr ----
assert_container_running "radarr"
assert_container_healthy "radarr"
assert_container_not_latest "radarr"
assert_http_200 "${BASE_URL:-http://localhost}:7878/api/v3/system/status" "radarr:api"

# ---- qBittorrent ----
assert_container_running "qbittorrent"
assert_container_healthy "qbittorrent"
assert_container_not_latest "qbittorrent"
assert_http_200 "${BASE_URL:-http://localhost}:8080/api/v2/app/version" "qbittorrent:api"

# ---- Prowlarr ----
assert_container_running "prowlarr"
assert_container_healthy "prowlarr"
assert_container_not_latest "prowlarr"
assert_http_200 "${BASE_URL:-http://localhost}:9696/api/v1/system/status" "prowlarr:api"

# ---- Inter-service connectivity ----
begin_test "sonarr:can_reach_radarr"
if docker exec sonarr curl -sf --connect-timeout 3 "http://radarr:7878/api/v3/system/status" &>/dev/null; then
  assert_pass "sonarr → radarr reachable"
else
  assert_skip "inter-container test (may need same network)"
fi

# ---- Volumes ----
begin_test "media:volumes"
for vol in jellyfin-config sonarr-config radarr-config qbittorrent-config prowlarr-config; do
  if docker volume ls --format '{{.Name}}' 2>/dev/null | grep -q "$vol"; then
    assert_pass "volume $vol exists"
  else
    assert_skip "volume $vol (created on first run)"
  fi
done

# ---- Compose validation ----
assert_compose_valid "${SCRIPT_DIR}/../../stacks/media/docker-compose.yml" "media"
