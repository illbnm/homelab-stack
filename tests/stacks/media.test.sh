#!/bin/bash
# =============================================================================
# media.test.sh - Media stack tests
# =============================================================================

test_compose_syntax() {
    local start=$(date +%s)
    local result="PASS"
    docker compose -f stacks/media/docker-compose.yml config --quiet 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "Compose syntax" "$result" $((end - start))
}

test_jellyfin_running() {
    local start=$(date +%s)
    local result="PASS"
    assert_container_running "jellyfin" 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "Jellyfin running" "$result" $((end - start))
}

test_sonarr_running() {
    local start=$(date +%s)
    local result="PASS"
    assert_container_running "sonarr" 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "Sonarr running" "$result" $((end - start))
}

test_radarr_running() {
    local start=$(date +%s)
    local result="PASS"
    assert_container_running "radarr" 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "Radarr running" "$result" $((end - start))
}

test_qbittorrent_running() {
    local start=$(date +%s)
    local result="PASS"
    assert_container_running "qbittorrent" 2>&1 || result="FAIL"
    local end=$(date +%s)
    print_test_result "qBittorrent running" "$result" $((end - start))
}

# Run all tests
test_compose_syntax
test_jellyfin_running
test_sonarr_running
test_radarr_running
test_qbittorrent_running
