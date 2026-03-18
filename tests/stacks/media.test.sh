#!/usr/bin/env bash
# media.test.sh - Tests for media stack (jellyfin, sonarr, radarr, prowlarr, qbittorrent, bazarr, tautulli)
# Copyright (c) 2026 homelab-stack contributors
# SPDX-License-Identifier: MIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"
source "${SCRIPT_DIR}/../lib/report.sh"

STACK_NAME="media"
SERVICES=(jellyfin sonarr radarr prowlarr qbittorrent bazarr tautulli)

setup() {
    assert_reset
    report_init "$STACK_NAME"
}

teardown() {
    report_write_json
    report_print_summary
}

test_compose_file_exists() {
    assert_set_test "compose_file_exists"
    local compose_file
    compose_file=$(get_compose_file "$STACK_NAME")
    assert_file_exists "$compose_file" "media compose file should exist"
}

test_all_services_defined() {
    assert_set_test "all_services_defined"
    local compose_file
    compose_file=$(get_compose_file "$STACK_NAME")
    for svc in "${SERVICES[@]}"; do
        assert_service_exists "$compose_file" "$svc"
    done
}

test_jellyfin_running() {
    assert_set_test "jellyfin_running"
    assert_container_running "jellyfin"
}

test_jellyfin_healthy() {
    assert_set_test "jellyfin_healthy"
    assert_container_healthy "jellyfin"
}

test_jellyfin_health_endpoint() {
    assert_set_test "jellyfin_health_endpoint"
    local ip
    ip=$(get_container_ip "jellyfin")
    if [ -n "$ip" ]; then
        assert_http_200 "http://${ip}:8096/health" "jellyfin health endpoint should respond 200"
    else
        _assert_skip "jellyfin health endpoint" "could not determine container IP"
    fi
}

test_sonarr_running() {
    assert_set_test "sonarr_running"
    assert_container_running "sonarr"
}

test_sonarr_http() {
    assert_set_test "sonarr_http"
    local ip
    ip=$(get_container_ip "sonarr")
    if [ -n "$ip" ]; then
        assert_http_200 "http://${ip}:8989" "sonarr web UI should respond"
    else
        _assert_skip "sonarr HTTP check" "could not determine container IP"
    fi
}

test_radarr_running() {
    assert_set_test "radarr_running"
    assert_container_running "radarr"
}

test_radarr_http() {
    assert_set_test "radarr_http"
    local ip
    ip=$(get_container_ip "radarr")
    if [ -n "$ip" ]; then
        assert_http_200 "http://${ip}:7878" "radarr web UI should respond"
    else
        _assert_skip "radarr HTTP check" "could not determine container IP"
    fi
}

test_prowlarr_running() {
    assert_set_test "prowlarr_running"
    assert_container_running "prowlarr"
}

test_qbittorrent_running() {
    assert_set_test "qbittorrent_running"
    assert_container_running "qbittorrent"
}

test_bazarr_running() {
    assert_set_test "bazarr_running"
    assert_container_running "bazarr"
}

test_tautulli_running() {
    assert_set_test "tautulli_running"
    assert_container_running "tautulli"
}

# --- Run ---
setup
for func in $(declare -F | grep -o 'test_' | sort); do
    echo -e "\n${_C_CYAN}▶ ${func}${_C_RESET}"
    $func
done
teardown
