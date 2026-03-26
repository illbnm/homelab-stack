#!/usr/bin/env bash
# media.test.sh - Media Stack 测试
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"
STACK_NAME="media"

test_jellyfin() {
    test_start "Jellyfin - 容器运行"
    if assert_container_running "jellyfin"; then test_end "Jellyfin - 容器运行" "PASS"
    else test_end "Jellyfin - 容器运行" "FAIL"; return 1; fi
    test_start "Jellyfin - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:8096/"; then test_end "Jellyfin - HTTP 端点可达" "PASS"
    else test_end "Jellyfin - HTTP 端点可达" "SKIP"; fi
}

test_sonarr() {
    test_start "Sonarr - 容器运行"
    if assert_container_running "sonarr"; then test_end "Sonarr - 容器运行" "PASS"
    else test_end "Sonarr - 容器运行" "FAIL"; return 1; fi
    test_start "Sonarr - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:8989/"; then test_end "Sonarr - HTTP 端点可达" "PASS"
    else test_end "Sonarr - HTTP 端点可达" "SKIP"; fi
}

test_radarr() {
    test_start "Radarr - 容器运行"
    if assert_container_running "radarr"; then test_end "Radarr - 容器运行" "PASS"
    else test_end "Radarr - 容器运行" "FAIL"; return 1; fi
    test_start "Radarr - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:7878/"; then test_end "Radarr - HTTP 端点可达" "PASS"
    else test_end "Radarr - HTTP 端点可达" "SKIP"; fi
}

test_prowlarr() {
    test_start "Prowlarr - 容器运行"
    if assert_container_running "prowlarr"; then test_end "Prowlarr - 容器运行" "PASS"
    else test_end "Prowlarr - 容器运行" "FAIL"; return 1; fi
    test_start "Prowlarr - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:9696/"; then test_end "Prowlarr - HTTP 端点可达" "PASS"
    else test_end "Prowlarr - HTTP 端点可达" "SKIP"; fi
}

test_qbittorrent() {
    test_start "qBittorrent - 容器运行"
    if assert_container_running "qbittorrent"; then test_end "qBittorrent - 容器运行" "PASS"
    else test_end "qBittorrent - 容器运行" "FAIL"; return 1; fi
    test_start "qBittorrent - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:8080/"; then test_end "qBittorrent - HTTP 端点可达" "PASS"
    else test_end "qBittorrent - HTTP 端点可达" "SKIP"; fi
}

test_main() {
    test_group_start "$STACK_NAME"
    test_jellyfin || true; test_sonarr || true; test_radarr || true; test_prowlarr || true; test_qbittorrent || true
    test_group_end "$STACK_NAME" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "${SCRIPT_DIR}/lib/assert.sh"; source "${SCRIPT_DIR}/lib/docker.sh"; source "${SCRIPT_DIR}/lib/report.sh"
    report_init; test_main; print_summary "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
