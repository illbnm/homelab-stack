#!/bin/bash
# =============================================================================
# Base Infrastructure Tests — HomeLab Stack
# =============================================================================
# Tests: Traefik, Portainer, Watchtower
# Level: 1 (container health) + 2 (HTTP endpoints) + 5 (config)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/docker.sh"
source "$TESTS_DIR/lib/report.sh"

load_env() {
    if [[ -f "$ROOT_DIR/.env" ]]; then
        set -a
        source "$ROOT_DIR/.env"
        set +a
    fi
}
load_env

suite_start "Base Infrastructure"

# Load domain from env (fallback for CI)
DOMAIN="${DOMAIN:-localhost}"

# Level 1 — Container Health Tests
test_traefik_container() {
    assert_container_running "traefik"
}

test_portainer_container() {
    assert_container_running "portainer"
}

test_watchtower_container() {
    assert_container_running "watchtower" || true
}

# Level 2 — HTTP Endpoint Tests
test_traefik_api() {
    assert_http_200 "http://localhost:8080/api/version"
}

test_traefik_dashboard() {
    assert_http_200 "http://localhost:8080/dashboard/" || \
    assert_http_200 "http://localhost:8080/"
}

test_portainer_api() {
    assert_http_200 "http://portainer:9000/api/status" 10 || \
    assert_http_200 "http://localhost:9000/api/status" 10
}

# Level 5 — Configuration Integrity Tests
test_compose_syntax() {
    local failed=0
    for f in $(find "$ROOT_DIR/stacks/base" -name 'docker-compose*.yml'); do
        if ! docker compose -f "$f" config --quiet 2>/dev/null; then
            echo "Invalid compose: $f"
            failed=1
        fi
    done
    [[ $failed -eq 0 ]]
}

test_no_latest_tags_in_base() {
    assert_no_latest_images "stacks/base"
}

# Run all tests
tests=(
    test_traefik_container
    test_portainer_container
    test_watchtower_container
    test_traefik_api
    test_traefik_dashboard
    test_portainer_api
    test_compose_syntax
    test_no_latest_tags_in_base
)

for test in "${tests[@]}"; do
    start=$(date +%s.%N)
    $test
    end=$(date +%s.%N)
    duration=$(echo "$end - $start" | bc)
done

summary
