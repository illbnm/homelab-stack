#!/usr/bin/env bash
# media.test.sh — Tests for the media stack

STACK_DIR="${REPO_ROOT}/stacks/media"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"

JELLYFIN_HOST="${JELLYFIN_HOST:-localhost}"
SONARR_HOST="${SONARR_HOST:-localhost}"
RADARR_HOST="${RADARR_HOST:-localhost}"
QBITTORRENT_HOST="${QBITTORRENT_HOST:-localhost}"

# ── Level 1: Configuration Integrity ──────────────────────────────────────────

if docker compose -f "$COMPOSE_FILE" config --quiet 2>/dev/null; then
  assert_pass "media: compose syntax valid"
else
  assert_fail "media: compose syntax valid" "docker compose config failed"
fi

assert_no_latest_images "media: no :latest image tags" "$COMPOSE_FILE"

# ── Level 1: Container Health ──────────────────────────────────────────────────

for container in jellyfin sonarr radarr qbittorrent; do
  if docker_container_exists "$container"; then
    assert_container_running "media: ${container} is running" "$container"
  else
    assert_skip "media: ${container} is running" "container not deployed"
  fi
done

# ── Level 2: HTTP Endpoints ────────────────────────────────────────────────────

if docker_container_exists "jellyfin"; then
  assert_http_200 "media: Jellyfin health" \
    "http://${JELLYFIN_HOST}:8096/health"
else
  assert_skip "media: Jellyfin health" "container not deployed"
fi

if docker_container_exists "sonarr"; then
  assert_http_200 "media: Sonarr ping" \
    "http://${SONARR_HOST}:8989/ping"
else
  assert_skip "media: Sonarr ping" "container not deployed"
fi

if docker_container_exists "radarr"; then
  assert_http_200 "media: Radarr ping" \
    "http://${RADARR_HOST}:7878/ping"
else
  assert_skip "media: Radarr ping" "container not deployed"
fi

if docker_container_exists "qbittorrent"; then
  assert_http_200 "media: qBittorrent web UI" \
    "http://${QBITTORRENT_HOST}:8080/"
else
  assert_skip "media: qBittorrent web UI" "container not deployed"
fi

# ── Level 3: Inter-Service Connectivity ───────────────────────────────────────

if docker_container_exists "sonarr" && docker_container_exists "qbittorrent"; then
  SONARR_API_KEY="${SONARR_API_KEY:-}"
  if [[ -n "$SONARR_API_KEY" ]]; then
    dl_clients=$(curl -s --max-time 10 \
      -H "X-Api-Key: ${SONARR_API_KEY}" \
      "http://${SONARR_HOST}:8989/api/v3/downloadclient" 2>/dev/null || echo '[]')
    if echo "$dl_clients" | jq -e '.[]? | select(.enable == true)' &>/dev/null; then
      assert_pass "media: Sonarr has enabled download client"
    else
      assert_skip "media: Sonarr has enabled download client" "no clients configured"
    fi
  else
    assert_skip "media: Sonarr-qBittorrent connectivity" "SONARR_API_KEY not set"
  fi
else
  assert_skip "media: Sonarr-qBittorrent connectivity" "containers not deployed"
fi
