#!/usr/bin/env bash
set -euo pipefail

test_jellyfin_running() { assert_container_healthy jellyfin; }
test_prowlarr_running() { assert_container_healthy prowlarr; }
test_qbittorrent_running() { assert_container_healthy qbittorrent; }
test_radarr_running() { assert_container_healthy radarr; }
test_sonarr_running() { assert_container_healthy sonarr; }
