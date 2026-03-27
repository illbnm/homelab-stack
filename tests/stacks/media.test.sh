#!/bin/bash
# =============================================================================
# Media Stack Tests — HomeLab Stack
# =============================================================================
# Tests: Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent
# Level: 1 (container health) + 2 (HTTP endpoints) + 5 (config)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/docker.sh"

load_env() {
    if [[ -f "$ROOT_DIR/.env" ]]; then
        set -a
        source "$ROOT_DIR/.env"
        set +a
    fi
}
load_env

suite_start "Media Stack"

# Level 1 — Container Health
test_jellyfin_running()    { assert_container_running "jellyfin"; }
test_sonarr_running()      { assert_container_running "sonarr"; }
test_radarr_running()      { assert_container_running "radarr"; }
test_prowlarr_running()    { assert_container_running "prowlarr"; }
test_qbittorrent_running() { assert_container_running "qbittorrent"; }

# Level 1 — Health
test_jellyfin_healthy()    { assert_container_healthy "jellyfin" 30; }
test_sonarr_healthy()      { assert_container_healthy "sonarr" 30; }
test_radarr_healthy()      { assert_container_healthy "radarr" 30; }

# Level 2 — HTTP Endpoints
test_jellyfin_http()       { assert_http_200 "http://jellyfin:8096/health" 15; }
test_sonarr_http()         { assert_http_200 "http://sonarr:8989/api/v3/system/status" 15; }
test_radarr_http()         { assert_http_200 "http://radarr:7878/api/v3/system/status" 15; }
test_prowlarr_http()       { assert_http_200 "http://prowlarr:9696/api/v1/health" 15; }
test_qbittorrent_http()    { assert_http_200 "http://qbittorrent:8080/api/v2.2.1/app/preferences" 15; }

# Level 5 — Config
test_compose_syntax() {
    local failed=0
    for f in $(find "$ROOT_DIR/stacks/media" -name 'docker-compose*.yml'); do
        docker compose -f "$f" config --quiet 2>/dev/null || { echo "Invalid: $f"; failed=1; }
    done
    [[ $failed -eq 0 ]]
}
test_no_latest_tags()      { assert_no_latest_images "stacks/media"; }

tests=(
    test_jellyfin_running test_sonarr_running test_radarr_running
    test_prowlarr_running test_qbittorrent_running
    test_jellyfin_healthy test_sonarr_healthy test_radarr_healthy
    test_jellyfin_http test_sonarr_http test_radarr_http
    test_prowlarr_http test_qbittorrent_http
    test_compose_syntax test_no_latest_tags
)

for t in "${tests[@]}"; do $t; done
summary
