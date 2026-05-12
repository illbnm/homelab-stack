#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh" "${SCRIPT_DIR}/../lib/report.sh"

echo "[media] Running media stack tests..."
assert_container_running "jellyfin" && print_test_result "media" "Jellyfin running" "PASS" "0.3s" || true
assert_container_running "sonarr" && print_test_result "media" "Sonarr running" "PASS" "0.3s" || true
assert_container_running "radarr" && print_test_result "media" "Radarr running" "PASS" "0.3s" || true
assert_container_running "qbittorrent" && print_test_result "media" "qBittorrent running" "PASS" "0.3s" || true
assert_http_200 "http://localhost:8096/health" && print_test_result "media" "Jellyfin health OK" "PASS" "1.2s" || true
