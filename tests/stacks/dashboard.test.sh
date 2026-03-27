#!/bin/bash
# =============================================================================
# Dashboard Stack Tests — HomeLab Stack
# =============================================================================
# Tests: Homepage, Homarr
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

suite_start "Dashboard Stack"

test_homepage_running()  { assert_container_running "homepage"; }
test_homarr_running()    { assert_container_running "homarr" || true; }

test_homepage_http()     { assert_http_200 "http://homepage:3000" 20 || true; }
test_homarr_http()       { assert_http_200 "http://homarr:3000" 15 || true; }

test_compose_syntax() {
    local failed=0
    for f in $(find "$ROOT_DIR/stacks/dashboard" -name 'docker-compose*.yml'); do
        docker compose -f "$f" config --quiet 2>/dev/null || { echo "Invalid: $f"; failed=1; }
    done
    [[ $failed -eq 0 ]]
}
test_no_latest_tags()     { assert_no_latest_images "stacks/dashboard"; }

tests=(test_homepage_running test_homarr_running
       test_homepage_http test_homarr_http
       test_compose_syntax test_no_latest_tags)

for t in "${tests[@]}"; do $t; done
summary
