#!/bin/bash

# SSO Integration Test Suite
# Tests Authentik SSO stack functionality including container health, database connectivity,
# API accessibility, OIDC provider setup, authentication flows, and error handling

set -euo pipefail

# Import test utilities
source "$(dirname "$0")/lib/assert.sh"
source "$(dirname "$0")/lib/docker.sh"

STACK_DIR="$(pwd)/stacks/sso"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"
TEST_TIMEOUT=120

# Test configuration
AUTHENTIK_URL="http://localhost:9000"
REDIS_HOST="localhost"
REDIS_PORT="6379"
POSTGRES_HOST="localhost"
POSTGRES_PORT="5432"

# Setup test environment
setup_sso_tests() {
    echo "Setting up SSO integration tests..."
    cd "$STACK_DIR"

    # Copy example env if needed
    if [[ ! -f .env ]]; then
        cp .env.example .env
        echo "Created .env from example"
    fi

    # Start stack
    docker-compose up -d

    # Wait for services to be ready
    sleep 30
}

# Cleanup test environment
teardown_sso_tests() {
    echo "Cleaning up SSO tests..."
    cd "$STACK_DIR"
    docker-compose down -v
}

# Test 1: Container Health Checks
test_authentik_containers_healthy() {
    echo "Testing Authentik container health..."

    assert_container_running "sso_authentik-server_1"
    assert_container_running "sso_authentik-worker_1"
    assert_container_running "sso_postgresql_1"
    assert_container_running "sso_redis_1"

    # Check health status
    local server_health
    server_health=$(docker inspect --format='{{.State.Health.Status}}' sso_authentik-server_1 || echo "none")
    if [[ "$server_health" == "healthy" || "$server_health" == "none" ]]; then
        echo "✓ Authentik server container is healthy"
    else
        echo "✗ Authentik server container health check failed: $server_health"
        return 1
    fi
}

# Test 2: Database Connectivity
test_database_connectivity() {
    echo "Testing database connectivity..."

    # Test PostgreSQL connection
    local pg_test
    pg_test=$(docker exec sso_postgresql_1 pg_isready -h localhost -p 5432 -U authentik || echo "failed")
    assert_eq "$pg_test" "localhost:5432 - accepting connections" "PostgreSQL should accept connections"

    # Test Redis connection
    local redis_test
    redis_test=$(docker exec sso_redis_1 redis-cli ping || echo "failed")
    assert_eq "$redis_test" "PONG" "Redis should respond to ping"

    echo "✓ Database connectivity verified"
}

# Test 3: API Accessibility
test_authentik_api_accessibility() {
    echo "Testing Authentik API accessibility..."

    # Wait for service to be fully ready
    local attempts=0
    while [[ $attempts -lt 24 ]]; do
        if curl -s -f "$AUTHENTIK_URL/api/v3/admin/overview/" > /dev/null 2>&1; then
            break
        fi
        echo "Waiting for Authentik API... (attempt $((attempts + 1))/24)"
        sleep 5
        ((attempts++))
    done

    assert_http_200 "$AUTHENTIK_URL/api/v3/admin/overview/" "Authentik admin API should be accessible"
    assert_http_200 "$AUTHENTIK_URL/if/flow/default-authentication-flow/" "Authentication flow should be accessible"

    echo "✓ Authentik API is accessible"
}

# Test 4: Web Interface Accessibility
test_web_interface() {
    echo "Testing Authentik web interface..."

    assert_http_200 "$AUTHENTIK_URL/" "Main web interface should be accessible"
    assert_http_200 "$AUTHENTIK_URL/if/admin/" "Admin interface should be accessible"

    # Check for expected content
    local homepage_content
    homepage_content=$(curl -s "$AUTHENTIK_URL/" || echo "failed")
    if [[ "$homepage_content" == *"authentik"* ]]; then
        echo "✓ Homepage contains expected Authentik content"
    else
        echo "✗ Homepage missing Authentik content"
        return 1
    fi
}

# Test 5: OIDC Provider Configuration
test_oidc_provider_setup() {
    echo "Testing OIDC provider configuration..."

    # Check for OIDC discovery endpoint
    assert_http_200 "$AUTHENTIK_URL/application/o/authorize/" "OIDC authorization endpoint should be accessible"

    # Test well-known configuration endpoint
    local oidc_config
    oidc_config=$(curl -s "$AUTHENTIK_URL/application/o/.well-known/openid_configuration" || echo "failed")
    if [[ "$oidc_config" == *"issuer"* && "$oidc_config" == *"authorization_endpoint"* ]]; then
        echo "✓ OIDC well-known configuration is valid"
    else
        echo "✗ OIDC configuration incomplete or missing"
        return 1
    fi
}

# Test 6: Authentication Flow Testing
test_authentication_flow() {
    echo "Testing authentication flow endpoints..."

    # Test default authentication flow
    assert_http_200 "$AUTHENTIK_URL/if/flow/default-authentication-flow/" "Default auth flow should be accessible"

    # Test enrollment flow if configured
    local enrollment_response
    enrollment_response=$(curl -s -o /dev/null -w "%{http_code}" "$AUTHENTIK_URL/if/flow/default-enrollment-flow/" || echo "000")
    if [[ "$enrollment_response" == "200" || "$enrollment_response" == "404" ]]; then
        echo "✓ Enrollment flow endpoint status is expected ($enrollment_response)"
    else
        echo "✗ Enrollment flow returned unexpected status: $enrollment_response"
        return 1
    fi
}

# Test 7: Static Assets Loading
test_static_assets() {
    echo "Testing static asset loading..."

    # Test CSS loading
    assert_http_200 "$AUTHENTIK_URL/static/dist/assets/authentik.css" "CSS assets should load"

    # Test JS loading
    assert_http_200 "$AUTHENTIK_URL/static/dist/assets/authentik.js" "JavaScript assets should load"

    echo "✓ Static assets are accessible"
}

# Test 8: Service Logs Verification
test_service_logs() {
    echo "Testing service logs for errors..."

    # Check Authentik server logs
    local server_logs
    server_logs=$(docker logs sso_authentik-server_1 --tail 50 2>&1 || echo "failed")
    if [[ "$server_logs" != *"ERROR"* && "$server_logs" != *"CRITICAL"* ]]; then
        echo "✓ Authentik server logs show no critical errors"
    else
        echo "⚠ Warning: Found errors in Authentik server logs"
        echo "$server_logs" | grep -E "(ERROR|CRITICAL)" | head -3
    fi

    # Check worker logs
    local worker_logs
    worker_logs=$(docker logs sso_authentik-worker_1 --tail 20 2>&1 || echo "failed")
    if [[ "$worker_logs" != *"ERROR"* && "$worker_logs" != *"CRITICAL"* ]]; then
        echo "✓ Authentik worker logs show no critical errors"
    else
        echo "⚠ Warning: Found errors in Authentik worker logs"
    fi
}

# Test 9: Database Schema Verification
test_database_schema() {
    echo "Testing database schema integrity..."

    # Check if migrations completed successfully
    local table_count
    table_count=$(docker exec sso_postgresql_1 psql -U authentik -d authentik -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' \n' || echo "0")

    if [[ "$table_count" -gt 10 ]]; then
        echo "✓ Database schema appears complete ($table_count tables)"
    else
        echo "✗ Database schema may be incomplete (only $table_count tables found)"
        return 1
    fi

    # Verify specific core tables exist
    local core_tables=("authentik_core_user" "authentik_core_application" "authentik_providers_oauth2_oauth2provider")
    for table in "${core_tables[@]}"; do
        local table_exists
        table_exists=$(docker exec sso_postgresql_1 psql -U authentik -d authentik -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = '$table');" 2>/dev/null | tr -d ' \n' || echo "f")
        if [[ "$table_exists" == "t" ]]; then
            echo "✓ Core table $table exists"
        else
            echo "✗ Core table $table missing"
            return 1
        fi
    done
}

# Test 10: Error Handling Scenarios
test_error_handling() {
    echo "Testing error handling scenarios..."

    # Test invalid endpoint returns proper error
    local invalid_response
    invalid_response=$(curl -s -o /dev/null -w "%{http_code}" "$AUTHENTIK_URL/invalid-endpoint-test" || echo "000")
    if [[ "$invalid_response" == "404" ]]; then
        echo "✓ Invalid endpoints return proper 404 status"
    else
        echo "✗ Invalid endpoint returned unexpected status: $invalid_response"
        return 1
    fi

    # Test malformed API request
    local api_error
    api_error=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$AUTHENTIK_URL/api/v3/admin/overview/" -H "Content-Type: application/json" -d '{"invalid": "data"}' || echo "000")
    if [[ "$api_error" == "405" || "$api_error" == "403" || "$api_error" == "401" ]]; then
        echo "✓ Malformed API requests handled properly (status: $api_error)"
    else
        echo "✗ API error handling unexpected: $api_error"
        return 1
    fi
}

# Test 11: Service Resource Usage
test_resource_usage() {
    echo "Testing service resource usage..."

    # Check memory usage of containers
    local services=("sso_authentik-server_1" "sso_authentik-worker_1" "sso_postgresql_1" "sso_redis_1")
    for service in "${services[@]}"; do
        local mem_usage
        mem_usage=$(docker stats "$service" --no-stream --format "{{.MemUsage}}" 2>/dev/null || echo "unknown")
        if [[ "$mem_usage" != "unknown" ]]; then
            echo "✓ $service memory usage: $mem_usage"
        else
            echo "⚠ Could not get memory stats for $service"
        fi
    done

    # Check if containers are restarting
    local restart_count
    restart_count=$(docker inspect --format='{{.RestartCount}}' sso_authentik-server_1 2>/dev/null || echo "unknown")
    if [[ "$restart_count" == "0" ]]; then
        echo "✓ Authentik server has not restarted"
    else
        echo "⚠ Authentik server restart count: $restart_count"
    fi
}

# Test 12: Configuration Validation
test_configuration_validation() {
    echo "Testing configuration validation..."

    # Check environment variables are loaded
    local env_check
    env_check=$(docker exec sso_authentik-server_1 printenv AUTHENTIK_SECRET_KEY 2>/dev/null || echo "missing")
    if [[ "$env_check" != "missing" && ${#env_check} -gt 10 ]]; then
        echo "✓ Secret key is configured"
    else
        echo "✗ Secret key configuration issue"
        return 1
    fi

    # Verify database configuration
    local db_config
    db_config=$(docker exec sso_authentik-server_1 printenv AUTHENTIK_POSTGRESQL__HOST 2>/dev/null || echo "missing")
    if [[ "$db_config" == "postgresql" ]]; then
        echo "✓ Database configuration is correct"
    else
        echo "✗ Database configuration issue: $db_config"
        return 1
    fi

    # Check Redis configuration
    local redis_config
    redis_config=$(docker exec sso_authentik-server_1 printenv AUTHENTIK_REDIS__HOST 2>/dev/null || echo "missing")
    if [[ "$redis_config" == "redis" ]]; then
        echo "✓ Redis configuration is correct"
    else
        echo "✗ Redis configuration issue: $redis_config"
        return 1
    fi
}

# Main test execution
main() {
    echo "Starting SSO Integration Tests..."

    setup_sso_tests

    local failed_tests=0
    local total_tests=12

    # Execute all tests
    test_authentik_containers_healthy || ((failed_tests++))
    test_database_connectivity || ((failed_tests++))
    test_authentik_api_accessibility || ((failed_tests++))
    test_web_interface || ((failed_tests++))
    test_oidc_provider_setup || ((failed_tests++))
    test_authentication_flow || ((failed_tests++))
    test_static_assets || ((failed_tests++))
    test_service_logs || ((failed_tests++))
    test_database_schema || ((failed_tests++))
    test_error_handling || ((failed_tests++))
    test_resource_usage || ((failed_tests++))
    test_configuration_validation || ((failed_tests++))

    teardown_sso_tests

    echo ""
    echo "SSO Integration Test Results:"
    echo "Passed: $((total_tests - failed_tests))/$total_tests"
    echo "Failed: $failed_tests/$total_tests"

    if [[ $failed_tests -eq 0 ]]; then
        echo "✅ All SSO integration tests passed!"
        exit 0
    else
        echo "❌ $failed_tests test(s) failed"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
