#!/bin/bash
# =============================================================================
# Notifications Stack Tests — HomeLab Stack
# =============================================================================
# Tests: ntfy, Gotify, Apprise
# Level: 1 (container health) + 2 (HTTP endpoints) + 5 (config)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/docker.sh"

load_env() {
    if [[ -f "$ROOT_DIR/.env" ]]; then
        set -a
        source "$ROOT_DIR/.env"
        set +a
    fi
}
load_env

suite_start "Notifications Stack"

# Level 1 — Container Health
test_ntfy_running() {
    assert_container_running "ntfy"
}

test_apprise_running() {
    assert_container_running "apprise"
}

test_gotify_running() {
    assert_container_running "gotify"
}

# Level 1 — Health Check
test_ntfy_healthy() {
    assert_container_healthy "ntfy" 30
}

test_gotify_healthy() {
    assert_http_200 "http://gotify:8080/ping" 20 || true
}

# Level 2 — HTTP Endpoints
test_ntfy_http() {
    local domain="${DOMAIN:-localhost}"
    if [[ "$domain" == "localhost" ]]; then
        assert_http_200 "http://localhost:8082/v1/health" 15 || true
    else
        assert_http_200 "http://ntfy.${domain}/v1/health" 15
    fi
}

test_apprise_http() {
    local domain="${DOMAIN:-localhost}"
    if [[ "$domain" == "localhost" ]]; then
        assert_http_200 "http://localhost:8083/" 15 || true
    else
        assert_http_200 "http://apprise.${domain}/" 15
    fi
}

test_gotify_http() {
    local domain="${DOMAIN:-localhost}"
    if [[ "$domain" == "localhost" ]]; then
        assert_http_200 "http://localhost:8084/" 15 || true
    else
        assert_http_200 "http://gotify.${domain}/" 15
    fi
}

# Level 5 — Configuration Integrity
test_compose_syntax() {
    local failed=0
    for f in $(find "$ROOT_DIR/stacks/notifications" -name 'docker-compose*.yml'); do
        docker compose -f "$f" config --quiet 2>/dev/null || {
            echo "Invalid compose: $f"
            failed=1
        }
    done
    [[ $failed -eq 0 ]]
}

test_no_latest_tags() {
    assert_no_latest_images "stacks/notifications"
}

test_ntfy_config_exists() {
    assert_file_contains "$ROOT_DIR/config/ntfy/server.yml" "base-url"
}

test_notify_script_exists() {
    assert_file_contains "$ROOT_DIR/scripts/notify.sh" "#!/bin/bash"
    assert_file_contains "$ROOT_DIR/scripts/notify.sh" "send_ntfy"
    assert_file_contains "$ROOT_DIR/scripts/notify.sh" "send_gotify"
}

test_notifications_readme_exists() {
    assert_file_contains "$ROOT_DIR/stacks/notifications/README.md" "Gotify"
    assert_file_contains "$ROOT_DIR/stacks/notifications/README.md" "ntfy"
}

# Run tests
tests=(
    test_ntfy_running
    test_apprise_running
    test_gotify_running
    test_ntfy_healthy
    test_gotify_healthy
    test_ntfy_http
    test_apprise_http
    test_gotify_http
    test_compose_syntax
    test_no_latest_tags
    test_ntfy_config_exists
    test_notify_script_exists
    test_notifications_readme_exists
)

for test in "${tests[@]}"; do
    $test
done

summary
