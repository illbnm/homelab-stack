#!/bin/bash
# =============================================================================
# Productivity Stack Tests — HomeLab Stack
# =============================================================================
# Tests: Gitea, Vaultwarden, Outline, BookStack
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

suite_start "Productivity Stack"

test_gitea_running()       { assert_container_running "gitea"; }
test_vaultwarden_running() { assert_container_running "vaultwarden"; }
test_outline_running()     { assert_container_running "outline"; }
test_bookstack_running()   { assert_container_running "bookstack" || true; }

test_gitea_http()          { assert_http_200 "http://gitea:3000/api/v1/version" 20; }
test_vaultwarden_http()    { assert_http_200 "http://vaultwarden:80" 15; }
test_outline_http()        { assert_http_200 "http://outline:3000/status" 20; }
test_bookstack_http()      { assert_http_200 "http://bookstack:80" 15 || true; }

test_compose_syntax() {
    local failed=0
    for f in $(find "$ROOT_DIR/stacks/productivity" -name 'docker-compose*.yml'); do
        docker compose -f "$f" config --quiet 2>/dev/null || { echo "Invalid: $f"; failed=1; }
    done
    [[ $failed -eq 0 ]]
}
test_no_latest_tags()       { assert_no_latest_images "stacks/productivity"; }

tests=(test_gitea_running test_vaultwarden_running test_outline_running test_bookstack_running
       test_gitea_http test_vaultwarden_http test_outline_http test_bookstack_http
       test_compose_syntax test_no_latest_tags)

for t in "${tests[@]}"; do $t; done
summary
