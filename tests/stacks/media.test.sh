#!/usr/bin/env bash
# Media Stack Tests — Jellyfin, Sonarr, Radarr, qBittorrent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"

reset_counters
log_test_start "Media Stack"

DOMAIN="${DOMAIN:-localhost}"
ENV_FILE="$ROOT_DIR/.env"
[[ -f "$ENV_FILE" ]] && export $(grep -v '^#' "$ENV_FILE" | xargs)

section "Jellyfin"
assert_container_running "Jellyfin container" "homelab-jellyfin"
assert_http_2xx "Jellyfin API accessible" "http://localhost:8097/health" || true

section "Sonarr"
assert_container_running "Sonarr container" "homelab-sonarr"
assert_http_2xx "Sonarr API accessible" "http://localhost:8989/ping" || true

section "Radarr"
assert_container_running "Radarr container" "homelab-radarr"
assert_http_2xx "Radarr API accessible" "http://localhost:7878/ping" || true

section "qBittorrent"
assert_container_running "qBittorrent container" "homelab-qbittorrent"
assert_http_2xx "qBittorrent WebUI accessible" "http://localhost:8088/api/v2/app/webapiVersion" || true

assert_summary