#!/usr/bin/env bash
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib"; pwd)"
source "$_LIB_DIR/assert.sh"

test_media_jellyfin_running() { assert_container_running "jellyfin" "Jellyfin should be running"; }
test_media_jellyfin_health() { assert_http_200 "http://localhost:8096/health" 15 "Jellyfin health endpoint"; }
test_media_sonarr_running() { assert_container_running "sonarr" "Sonarr should be running"; }
test_media_radarr_running() { assert_container_running "radarr" "Radarr should be running"; }
test_media_qbittorrent_running() { assert_container_running "qbittorrent" "qBittorrent should be running"; }
test_media_no_latest_tags() { assert_no_latest_images "$BASE_DIR/stacks/media" "Media stack should pin image versions"; }
