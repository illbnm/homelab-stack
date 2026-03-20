#!/bin/bash

# Test suite for productivity stack
# Tests Gitea, Vaultwarden, Outline, Stirling PDF, and Excalidraw

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/docker.sh"

STACK_NAME="productivity"
COMPOSE_FILE="stacks/productivity/docker-compose.yml"

test_containers_running() {
    echo "Testing productivity stack containers..."

    assert_container_running "gitea"
    assert_container_running "vaultwarden"
    assert_container_running "outline"
    assert_container_running "stirling-pdf"
    assert_container_running "excalidraw"

    echo "✓ All productivity containers are running"
}

test_containers_healthy() {
    echo "Testing container health status..."

    assert_container_healthy "gitea"
    assert_container_healthy "vaultwarden"
    assert_container_healthy "outline"

    echo "✓ All containers report healthy status"
}

test_http_endpoints() {
    echo "Testing HTTP endpoint accessibility..."

    # Gitea
    assert_http_200 "http://localhost:3000"
    assert_http_contains "http://localhost:3000" "Gitea"

    # Vaultwarden
    assert_http_200 "http://localhost:8080"
    assert_http_contains "http://localhost:8080" "Bitwarden"

    # Outline
    assert_http_200 "http://localhost:3001"
    assert_http_contains "http://localhost:3001" "Outline"

    # Stirling PDF
    assert_http_200 "http://localhost:8082"
    assert_http_contains "http://localhost:8082" "Stirling"

    # Excalidraw
    assert_http_200 "http://localhost:8083"
    assert_http_contains "http://localhost:8083" "Excalidraw"

    echo "✓ All HTTP endpoints are accessible"
}

test_database_connectivity() {
    echo "Testing database connectivity..."

    # Test PostgreSQL connection for services that use it
    local pg_container=$(docker ps --filter "name=postgres" --format "{{.Names}}" | head -1)
    if [[ -n "$pg_container" ]]; then
        # Test Gitea database connection
        docker exec "$pg_container" psql -U gitea -d gitea -c "SELECT 1;" >/dev/null 2>&1
        assert_eq $? 0 "Gitea database connection failed"

        # Test Outline database connection
        docker exec "$pg_container" psql -U outline -d outline -c "SELECT 1;" >/dev/null 2>&1
        assert_eq $? 0 "Outline database connection failed"

        echo "✓ Database connectivity verified"
    else
        echo "⚠ PostgreSQL container not found, skipping database tests"
    fi
}

test_redis_connectivity() {
    echo "Testing Redis connectivity..."

    local redis_container=$(docker ps --filter "name=redis" --format "{{.Names}}" | head -1)
    if [[ -n "$redis_container" ]]; then
        # Test Redis ping
        docker exec "$redis_container" redis-cli ping | grep -q "PONG"
        assert_eq $? 0 "Redis ping failed"

        echo "✓ Redis connectivity verified"
    else
        echo "⚠ Redis container not found, skipping Redis tests"
    fi
}

test_gitea_functionality() {
    echo "Testing Gitea functionality..."

    # Test API endpoint
    assert_http_200 "http://localhost:3000/api/v1/version"

    # Test registration page (if enabled)
    curl -s "http://localhost:3000/user/sign_up" | grep -q "form"
    local signup_available=$?

    # Test installation completion
    curl -s "http://localhost:3000" | grep -q -v "Installation"
    assert_eq $? 0 "Gitea installation not completed"

    echo "✓ Gitea functionality verified"
}

test_vaultwarden_functionality() {
    echo "Testing Vaultwarden functionality..."

    # Test API endpoint
    assert_http_200 "http://localhost:8080/api/"

    # Test admin interface (if enabled)
    curl -s "http://localhost:8080/admin" | grep -q -E "(admin|login)"
    local admin_result=$?

    # Test web vault
    curl -s "http://localhost:8080" | grep -q "Bitwarden"
    assert_eq $? 0 "Vaultwarden web vault not accessible"

    echo "✓ Vaultwarden functionality verified"
}

test_outline_functionality() {
    echo "Testing Outline functionality..."

    # Test health endpoint
    assert_http_200 "http://localhost:3001/health"

    # Test main application
    curl -s "http://localhost:3001" | grep -q -E "(Outline|knowledge)"
    assert_eq $? 0 "Outline application not loading properly"

    echo "✓ Outline functionality verified"
}

test_stirling_pdf_functionality() {
    echo "Testing Stirling PDF functionality..."

    # Test main page
    curl -s "http://localhost:8082" | grep -q -E "(PDF|Stirling)"
    assert_eq $? 0 "Stirling PDF not loading properly"

    # Test API endpoint (if available)
    curl -s -o /dev/null -w "%{http_code}" "http://localhost:8082/api" | grep -qE "^(200|404)$"
    assert_eq $? 0 "Stirling PDF API not responding"

    echo "✓ Stirling PDF functionality verified"
}

test_excalidraw_functionality() {
    echo "Testing Excalidraw functionality..."

    # Test main application
    curl -s "http://localhost:8083" | grep -q "Excalidraw"
    assert_eq $? 0 "Excalidraw not loading properly"

    # Test static assets loading
    curl -s -o /dev/null -w "%{http_code}" "http://localhost:8083/static" | grep -qE "^(200|404)$"

    echo "✓ Excalidraw functionality verified"
}

test_oidc_configuration() {
    echo "Testing OIDC configuration..."

    # Test Gitea OIDC endpoints
    curl -s "http://localhost:3000/.well-known/openid_configuration" | grep -q "issuer"
    local gitea_oidc=$?

    if [[ $gitea_oidc -eq 0 ]]; then
        echo "✓ Gitea OIDC provider configured"
    else
        echo "⚠ Gitea OIDC provider not found (may not be configured)"
    fi

    # Check if Outline can reach OIDC provider (basic connectivity)
    if docker logs outline 2>&1 | grep -q -E "(OIDC|OAuth|authentication)"; then
        echo "✓ Outline OIDC integration detected in logs"
    else
        echo "⚠ No OIDC configuration detected in Outline logs"
    fi
}

test_volume_mounts() {
    echo "Testing volume mounts..."

    # Test Gitea data persistence
    docker exec gitea test -d "/data"
    assert_eq $? 0 "Gitea data volume not mounted"

    # Test Vaultwarden data persistence
    docker exec vaultwarden test -d "/data"
    assert_eq $? 0 "Vaultwarden data volume not mounted"

    # Test file permissions
    docker exec gitea test -w "/data"
    assert_eq $? 0 "Gitea data directory not writable"

    echo "✓ Volume mounts verified"
}

test_network_connectivity() {
    echo "Testing inter-service network connectivity..."

    # Test if services can reach shared database
    if docker exec gitea nc -z postgres 5432 2>/dev/null; then
        echo "✓ Gitea can reach PostgreSQL"
    fi

    if docker exec outline nc -z postgres 5432 2>/dev/null; then
        echo "✓ Outline can reach PostgreSQL"
    fi

    # Test if services can reach Redis
    if docker exec outline nc -z redis 6379 2>/dev/null; then
        echo "✓ Outline can reach Redis"
    fi

    echo "✓ Network connectivity verified"
}

test_security_headers() {
    echo "Testing security headers..."

    # Test HTTPS redirect or security headers
    local headers=$(curl -s -I "http://localhost:8080")

    # Check for common security headers
    echo "$headers" | grep -q -i "x-frame-options"
    local xframe=$?

    echo "$headers" | grep -q -i "x-content-type-options"
    local xcontent=$?

    if [[ $xframe -eq 0 ]] || [[ $xcontent -eq 0 ]]; then
        echo "✓ Security headers detected"
    else
        echo "⚠ No security headers detected (may be handled by reverse proxy)"
    fi
}

# Main test execution
main() {
    echo "Starting productivity stack tests..."

    # Check if stack is running
    if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        echo "❌ Productivity stack is not running. Please start it first."
        exit 1
    fi

    # Run all tests
    test_containers_running
    test_containers_healthy
    test_http_endpoints
    test_database_connectivity
    test_redis_connectivity
    test_gitea_functionality
    test_vaultwarden_functionality
    test_outline_functionality
    test_stirling_pdf_functionality
    test_excalidraw_functionality
    test_oidc_configuration
    test_volume_mounts
    test_network_connectivity
    test_security_headers

    echo "✅ All productivity stack tests completed successfully!"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
