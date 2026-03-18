#!/usr/bin/env bash
# =============================================================================
# Media Stack Tests
# Tests for Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, Jellyseerr
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

print_section "Media Stack"

# Test containers
container_check jellyfin
container_check sonarr
container_check radarr
container_check prowlarr
container_check qbittorrent

# Test HTTP endpoints
http_check Jellyfin "http://localhost:8096/health"