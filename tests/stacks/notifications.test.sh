#!/bin/bash

# notifications.test.sh - Test suite for Gotify + Apprise notification stack
# Tests: Gotify server health, Apprise API, webhook endpoints, notification delivery

set -euo pipefail

# Load test libraries
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docker.sh"

readonly STACK_NAME="notifications"
readonly GOTIFY_URL="${GOTIFY_URL:-http://localhost:8085}"
readonly APPRISE_URL="${APPRISE_URL:-http://localhost:8086}"

test_notifications_stack_running() {
    echo "Testing notifications stack containers..."

    assert_container_running "gotify"
    assert_container_running "apprise-api"

    echo "✓ All notification containers are running"
}

test_gotify_health() {
    echo "Testing Gotify server health..."

    assert_http_200 "$GOTIFY_URL/health"
    assert_http_200 "$GOTIFY_URL/version"

    # Test Gotify web interface
    local response
    response=$(curl -s "$GOTIFY_URL" | grep -o "Gotify" | head -1 || echo "")
    assert_eq "$response" "Gotify" "Gotify web interface should be accessible"

    echo "✓ Gotify server is healthy"
}

test_apprise_api_health() {
    echo "Testing Apprise API health..."

    assert_http_200 "$APPRISE_URL/"

    # Test Apprise config endpoint
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "$APPRISE_URL/config")
    assert_eq "$status_code" "405" "Apprise config endpoint should return 405 for GET"

    echo "✓ Apprise API is healthy"
}

test_gotify_authentication() {
    echo "Testing Gotify authentication..."

    # Test unauthorized access to apps endpoint
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "$GOTIFY_URL/application")
    assert_eq "$status_code" "401" "Gotify should require authentication"

    # Test with admin credentials if available
    if [[ -n "${GOTIFY_ADMIN_USER:-}" && -n "${GOTIFY_ADMIN_PASS:-}" ]]; then
        status_code=$(curl -s -o /dev/null -w "%{http_code}" \
            -u "$GOTIFY_ADMIN_USER:$GOTIFY_ADMIN_PASS" \
            "$GOTIFY_URL/application")
        assert_eq "$status_code" "200" "Gotify should accept valid credentials"
    fi

    echo "✓ Gotify authentication is working"
}

test_apprise_notification_send() {
    echo "Testing Apprise notification sending..."

    # Test notification POST endpoint structure
    local response
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"urls": [], "body": "Test notification"}' \
        "$APPRISE_URL/notify" || echo "")

    # Should return JSON response even with empty URLs
    if echo "$response" | grep -q "error\|success"; then
        echo "✓ Apprise notification endpoint is responsive"
    else
        echo "⚠ Apprise notification endpoint returned unexpected response"
    fi
}

test_webhook_endpoints() {
    echo "Testing webhook endpoints..."

    # Test Gotify webhook endpoint structure
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"message": "test"}' \
        "$GOTIFY_URL/message" || echo "000")

    # Should require authentication (401) or token (400 for malformed)
    if [[ "$status_code" == "401" || "$status_code" == "400" ]]; then
        echo "✓ Gotify webhook endpoint is accessible and secured"
    else
        echo "⚠ Gotify webhook returned unexpected status: $status_code"
    fi
}

test_notification_persistence() {
    echo "Testing notification data persistence..."

    # Check if Gotify data directory is properly mounted
    local container_id
    container_id=$(docker ps -q -f "name=gotify")

    if [[ -n "$container_id" ]]; then
        local mount_info
        mount_info=$(docker inspect "$container_id" | grep -o "/app/data" || echo "")
        if [[ -n "$mount_info" ]]; then
            echo "✓ Gotify data directory is mounted"
        else
            echo "⚠ Gotify data persistence may not be configured"
        fi
    fi
}

test_service_integration() {
    echo "Testing service integration capabilities..."

    # Test if services can communicate with each other
    local gotify_reachable apprise_reachable

    # Test from Apprise container to Gotify
    gotify_reachable=$(docker exec apprise-api \
        curl -s -o /dev/null -w "%{http_code}" \
        "http://gotify:80/health" 2>/dev/null || echo "000")

    # Test from Gotify container to Apprise
    apprise_reachable=$(docker exec gotify \
        curl -s -o /dev/null -w "%{http_code}" \
        "http://apprise-api:8000/" 2>/dev/null || echo "000")

    if [[ "$gotify_reachable" == "200" ]]; then
        echo "✓ Apprise can reach Gotify internally"
    else
        echo "⚠ Internal service communication may have issues"
    fi

    if [[ "$apprise_reachable" == "200" ]]; then
        echo "✓ Gotify can reach Apprise internally"
    fi
}

test_environment_configuration() {
    echo "Testing environment configuration..."

    # Check critical environment variables are set in containers
    local gotify_tz apprise_debug

    gotify_tz=$(docker exec gotify printenv TZ 2>/dev/null || echo "")
    if [[ -n "$gotify_tz" ]]; then
        echo "✓ Gotify timezone is configured: $gotify_tz"
    fi

    # Test Apprise configuration loading
    apprise_debug=$(docker exec apprise-api printenv APPRISE_RECURSION_MAX 2>/dev/null || echo "")
    if [[ -n "$apprise_debug" ]]; then
        echo "✓ Apprise environment variables are configured"
    fi
}

run_notifications_tests() {
    echo "🔔 Running notifications stack tests..."

    test_notifications_stack_running
    test_gotify_health
    test_apprise_api_health
    test_gotify_authentication
    test_apprise_notification_send
    test_webhook_endpoints
    test_notification_persistence
    test_service_integration
    test_environment_configuration

    echo "✅ All notifications tests completed"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_notifications_tests
fi
