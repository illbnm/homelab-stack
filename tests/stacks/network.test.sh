#!/bin/bash
# =============================================================================
# Network Stack Tests — HomeLab Stack
# =============================================================================
# Tests: AdGuard Home, Nginx Proxy Manager
# Level: 1 + 2 + 5
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/docker.sh"

load_env() {
    [[ -f "$ROOT_DIR/.env" ]] && set -a && source "$ROOT_DIR/.env" && set +a
}
load_env

suite_start "Network Stack"

test_adguard_running()         { assert_container_running "adguardhome"; }
test_nginx_proxy_manager_running() { assert_container_running "nginx-proxy-manager" || true; }

test_adguard_http()             { assert_http_200 "http://adguardhome:3000/control/status" 20; }
test_nginx_proxy_manager_http()  { assert_http_200 "http://nginx-proxy-manager:81" 15 || true; }

test_compose_syntax() {
    local failed=0
    for f in $(find "$ROOT_DIR/stacks/network" -name 'docker-compose*.yml'); do
        docker compose -f "$f" config --quiet 2>/dev/null || { echo "Invalid: $f"; failed=1; }
    done
    [[ $failed -eq 0 ]]
}
test_no_latest_tags()            { assert_no_latest_images "stacks/network"; }

tests=(test_adguard_running test_nginx_proxy_manager_running
       test_adguard_http test_nginx_proxy_manager_http
       test_compose_syntax test_no_latest_tags)

for t in "${tests[@]}"; do $t; done
summary
