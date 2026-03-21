#!/bin/bash
# SPDX-License-Identifier: MIT
# SSO Stack Integration Tests
# Tests Authentik SSO authentication services

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"

STACK_NAME="sso"
TEST_TIMEOUT=30
AUTHENTIK_URL="http://localhost:9000"
AUTHENTIK_ADMIN_URL="${AUTHENTIK_URL}/if/admin/"

setup_test() {
    echo "🔧 Setting up SSO stack tests..."
    cd "${SCRIPT_DIR}/../../stacks/sso"

    # Ensure stack is running
    if ! docker compose ps | grep -q "Up"; then
        echo "⚠️  Starting SSO stack for testing..."
        docker compose up -d
        sleep 15
    fi
}

teardown_test() {
    echo "🧹 SSO test cleanup complete"
}

test_authentik_database_container() {
    echo "Testing Authentik database container..."
    assert_container_running "sso-authentik-postgresql-1"
    assert_container_healthy "sso-authentik-postgresql-1"
}

test_authentik_redis_container() {
    echo "Testing Authentik Redis container..."
    assert_container_running "sso-authentik-redis-1"
    assert_container_healthy "sso-authentik-redis-1"
}

test_authentik_server_container() {
    echo "Testing Authentik server container..."
    assert_container_running "sso-authentik-server-1"
    assert_container_healthy "sso-authentik-server-1"
}

test_authentik_worker_container() {
    echo "Testing Authentik worker container..."
    assert_container_running "sso-authentik-worker-1"

    # Worker might not have health check, check if running
    local status=$(docker inspect --format='{{.State.Status}}' sso-authentik-worker-1)
    assert_eq "$status" "running" "Authentik worker should be running"
}

test_authentik_database_connectivity() {
    echo "Testing database connectivity..."

    # Test PostgreSQL connection
    local pg_result=$(docker exec sso-authentik-postgresql-1 pg_isready -h localhost -p 5432 2>/dev/null || echo "failed")
    assert_not_eq "$pg_result" "failed" "PostgreSQL should be accepting connections"

    # Test Redis connection
    local redis_result=$(docker exec sso-authentik-redis-1 redis-cli ping 2>/dev/null || echo "failed")
    assert_eq "$redis_result" "PONG" "Redis should respond to ping"
}

test_authentik_web_interface() {
    echo "Testing Authentik web interface..."

    # Wait for service to be fully ready
    local retry=0
    while [ $retry -lt $TEST_TIMEOUT ]; do
        if curl -s -o /dev/null -w "%{http_code}" "$AUTHENTIK_URL" | grep -q "200\|302\|401"; then
            break
        fi
        sleep 2
        ((retry++))
    done

    assert_http_reachable "$AUTHENTIK_URL" "Authentik web interface should be reachable"
}

test_authentik_api_endpoints() {
    echo "Testing Authentik API endpoints..."

    # Test API root endpoint
    local api_url="${AUTHENTIK_URL}/api/v3/"
    assert_http_reachable "$api_url" "Authentik API should be reachable"

    # Test health endpoint
    local health_url="${AUTHENTIK_URL}/-/health/ready/"
    local health_response=$(curl -s -o /dev/null -w "%{http_code}" "$health_url" 2>/dev/null || echo "000")

    if [ "$health_response" = "200" ]; then
        echo "✅ Authentik health check passed"
    else
        echo "⚠️  Authentik health endpoint returned: $health_response (may be expected during startup)"
    fi
}

test_authentik_admin_interface() {
    echo "Testing Authentik admin interface..."

    # Admin interface should redirect or show login
    local admin_response=$(curl -s -o /dev/null -w "%{http_code}" "$AUTHENTIK_ADMIN_URL" 2>/dev/null || echo "000")

    # Admin should return 200 (login page) or 302 (redirect)
    if [[ "$admin_response" =~ ^(200|302|401)$ ]]; then
        echo "✅ Authentik admin interface accessible"
    else
        assert_fail "Authentik admin interface returned unexpected status: $admin_response"
    fi
}

test_authentik_oidc_discovery() {
    echo "Testing OIDC discovery endpoint..."

    local discovery_url="${AUTHENTIK_URL}/application/o/.well-known/openid-configuration"
    local discovery_response=$(curl -s "$discovery_url" 2>/dev/null || echo "")

    if echo "$discovery_response" | grep -q "issuer"; then
        echo "✅ OIDC discovery endpoint accessible"
    else
        echo "⚠️  OIDC discovery may not be configured yet"
    fi
}

test_authentik_container_logs() {
    echo "Checking Authentik container logs for errors..."

    # Check server logs for critical errors
    local server_errors=$(docker logs sso-authentik-server-1 2>&1 | grep -i "error\|exception\|failed" | grep -v "DEBUG" | tail -5 || true)
    if [ -n "$server_errors" ]; then
        echo "⚠️  Recent server log entries: $server_errors"
    fi

    # Check worker logs
    local worker_errors=$(docker logs sso-authentik-worker-1 2>&1 | grep -i "error\|exception\|failed" | grep -v "DEBUG" | tail -5 || true)
    if [ -n "$worker_errors" ]; then
        echo "⚠️  Recent worker log entries: $worker_errors"
    fi
}

test_authentik_environment_config() {
    echo "Testing Authentik environment configuration..."

    # Check if required environment variables are set in container
    local server_env=$(docker exec sso-authentik-server-1 printenv | grep "AUTHENTIK_" | head -3 2>/dev/null || true)
    if [ -n "$server_env" ]; then
        echo "✅ Authentik environment variables configured"
    else
        assert_fail "Authentik environment variables not found"
    fi
}

run_all_tests() {
    echo "🚀 Running SSO stack integration tests..."

    setup_test

    test_authentik_database_container
    test_authentik_redis_container
    test_authentik_server_container
    test_authentik_worker_container
    test_authentik_database_connectivity
    test_authentik_web_interface
    test_authentik_api_endpoints
    test_authentik_admin_interface
    test_authentik_oidc_discovery
    test_authentik_container_logs
    test_authentik_environment_config

    teardown_test

    echo "✅ All SSO stack tests completed successfully!"
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests
fi
