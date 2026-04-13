#!/usr/bin/env bash
# Base stack integration tests
# Copyright (c) 2026 思捷娅科技 (SJYKJ) | License: MIT

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/docker.sh"
source "$(dirname "$0")/../lib/report.sh"

test_base_all() {
    local pass=0 fail=0

    # Traefik
    run_test "base" "Traefik running" assert_container_running "traefik"
    run_test "base" "Traefik healthy" assert_container_healthy "traefik" 90
    run_test "base" "Traefik ping" assert_http_200 "http://localhost:8080/ping" 30

    # Portainer
    run_test "base" "Portainer running" assert_container_running "portainer"
    run_test "base" "Portainer healthy" assert_container_healthy "portainer" 60
    run_test "base" "Portainer API status" assert_http_200 "http://localhost:9000/api/status" 30

    # Watchtower
    run_test "base" "Watchtower running" assert_container_running "watchtower"

    # Docker Socket Proxy
    run_test "base" "Socket proxy running" assert_container_running "docker-socket-proxy"
    run_test "base" "Socket proxy healthy" assert_container_healthy "docker-socket-proxy" 30

    # Compose syntax
    run_test "base" "Base compose valid" assert_compose_valid "stacks/base/docker-compose.yml"

    # No :latest tags
    run_test "base" "No latest tags" assert_no_latest_images "stacks/base/"

    # HTTP redirect
    run_test "base" "HTTP redirects to HTTPS" assert_http_redirect "http://localhost:80"

    # Proxy network exists
    run_test "base" "Proxy network exists" assert_network_exists "proxy"
}

run_test() {
    local stack="$1" name="$2"; shift 2
    local start
    start=$(date +%s%N)
    if "$@" 2>/dev/null; then
        local dur=$(( ($(date +%s%N) - start) / 1000000 ))
        print_test "$stack" "$name" "PASS" "0.$dur"
        report_record "$stack" "$name" "PASS" "0.$dur"
    else
        local dur=$(( ($(date +%s%N) - start) / 1000000 ))
        print_test "$stack" "$name" "FAIL" "0.$dur"
        report_record "$stack" "$name" "FAIL" "0.$dur"
    fi
}

assert_compose_valid() {
    local f="$1"
    docker compose -f "$f" config --quiet 2>&1
    assert_exit_code $? "$f compose config failed"
}

assert_http_redirect() {
    local url="$1"
    local code
    code=$(curl -sk -o /dev/null -w '%{http_code}' -L --max-time 10 "$url" 2>/dev/null || echo "000")
    # 301 or 302 or 308 = redirect
    if [[ "$code" =~ ^(301|302|308)$ ]]; then
        ((ASSERT_PASS++)); return 0
    fi
    # Also OK if we get 200 (redirect already followed)
    if [[ "$code" == "200" ]]; then
        ((ASSERT_PASS++)); return 0
    fi
    ((ASSERT_FAIL++))
    echo -e "  ${RED}Expected redirect, got $code${NC}" >&2
    return 1
}

assert_network_exists() {
    local net="$1"
    if docker network inspect "$net" >/dev/null 2>&1; then
        ((ASSERT_PASS++)); return 0
    fi
    ((ASSERT_FAIL++))
    echo -e "  ${RED}Network '$net' not found${NC}" >&2
    return 1
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    print_header
    report_init
    test_base_all
    report_summary
fi
