#!/bin/bash
# SSO Integration Test Suite
# Tests Authentik SSO stack with OIDC provider creation and authentication flows

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

AUTHENTIK_URL="${AUTHENTIK_URL:-https://auth.homelab.local}"
STACK_NAME="sso"

# Test container health for SSO stack
test_sso_containers_running() {
    log_test "SSO containers health check"

    assert_container_running "authentik-server"
    assert_container_running "authentik-worker"
    assert_container_running "authentik-db"
    assert_container_running "authentik-redis"

    assert_container_healthy "authentik-server"
    assert_container_healthy "authentik-db"
    assert_container_healthy "authentik-redis"

    log_pass "All SSO containers are running and healthy"
}

# Test Authentik web interface accessibility
test_authentik_web_interface() {
    log_test "Authentik web interface accessibility"

    # Test main interface
    assert_http_200 "$AUTHENTIK_URL/if/flow/initial-setup/"
    assert_http_200 "$AUTHENTIK_URL/if/admin/"

    # Test API endpoints
    assert_http_200 "$AUTHENTIK_URL/api/v3/core/users/"
    assert_http_200 "$AUTHENTIK_URL/api/v3/core/applications/"

    log_pass "Authentik web interface is accessible"
}

# Test database connectivity
test_database_connectivity() {
    log_test "Database connectivity"

    # Test PostgreSQL connection
    docker exec authentik-db psql -U authentik -d authentik -c "SELECT 1;" > /dev/null

    # Test Redis connection
    docker exec authentik-redis redis-cli ping | grep -q "PONG"

    log_pass "Database connections are working"
}

# Test OIDC provider creation via API
test_oidc_provider_creation() {
    log_test "OIDC provider creation"

    local admin_token
    admin_token=$(get_authentik_admin_token)

    # Test creating a sample OIDC provider
    local provider_response
    provider_response=$(curl -s -X POST "$AUTHENTIK_URL/api/v3/providers/oauth2/" \
        -H "Authorization: Bearer $admin_token" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "test-provider",
            "client_type": "confidential",
            "authorization_grant_type": "authorization-code",
            "redirect_uris": "https://test.homelab.local/callback"
        }')

    echo "$provider_response" | jq -e '.pk' > /dev/null

    log_pass "OIDC provider creation successful"
}

# Test application creation
test_application_creation() {
    log_test "Application creation"

    local admin_token
    admin_token=$(get_authentik_admin_token)

    # Create test application
    local app_response
    app_response=$(curl -s -X POST "$AUTHENTIK_URL/api/v3/core/applications/" \
        -H "Authorization: Bearer $admin_token" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "test-app",
            "slug": "test-app",
            "meta_description": "Test application for integration tests"
        }')

    echo "$app_response" | jq -e '.slug' | grep -q "test-app"

    log_pass "Application creation successful"
}

# Test authentication flow
test_authentication_flow() {
    log_test "Authentication flow"

    # Test default authentication flow exists
    local admin_token
    admin_token=$(get_authentik_admin_token)

    local flow_response
    flow_response=$(curl -s -H "Authorization: Bearer $admin_token" \
        "$AUTHENTIK_URL/api/v3/flows/instances/?slug=default-authentication-flow")

    echo "$flow_response" | jq -e '.results[0].slug' > /dev/null

    log_pass "Authentication flow is configured"
}

# Test OIDC endpoints discovery
test_oidc_discovery() {
    log_test "OIDC discovery endpoint"

    local discovery_response
    discovery_response=$(curl -s "$AUTHENTIK_URL/application/o/.well-known/openid-configuration")

    echo "$discovery_response" | jq -e '.issuer' > /dev/null
    echo "$discovery_response" | jq -e '.authorization_endpoint' > /dev/null
    echo "$discovery_response" | jq -e '.token_endpoint' > /dev/null
    echo "$discovery_response" | jq -e '.userinfo_endpoint' > /dev/null

    log_pass "OIDC discovery endpoint is working"
}

# Test integrated services OIDC configuration
test_integrated_services_config() {
    log_test "Integrated services OIDC configuration"

    local services=("grafana" "gitea" "outline" "open-webui" "nextcloud" "bookstack" "portainer")
    local admin_token
    admin_token=$(get_authentik_admin_token)

    for service in "${services[@]}"; do
        # Check if OIDC provider exists for service
        local provider_response
        provider_response=$(curl -s -H "Authorization: Bearer $admin_token" \
            "$AUTHENTIK_URL/api/v3/providers/oauth2/?name__icontains=$service")

        local provider_count
        provider_count=$(echo "$provider_response" | jq '.count')

        if [[ "$provider_count" -gt 0 ]]; then
            log_info "✓ $service OIDC provider configured"
        else
            log_warn "⚠ $service OIDC provider not found"
        fi
    done

    log_pass "Service OIDC configuration check completed"
}

# Test ForwardAuth middleware configuration
test_forwardauth_middleware() {
    log_test "ForwardAuth middleware configuration"

    # Test ForwardAuth endpoint
    local auth_response
    auth_response=$(curl -s -o /dev/null -w "%{http_code}" \
        "$AUTHENTIK_URL/outpost.goauthentik.io/auth/traefik")

    # Should return 401 or redirect (3xx) for unauthenticated request
    if [[ "$auth_response" == "401" ]] || [[ "$auth_response" =~ ^3[0-9][0-9]$ ]]; then
        log_pass "ForwardAuth middleware is responding correctly"
    else
        log_fail "ForwardAuth middleware returned unexpected status: $auth_response"
    fi
}

# Test user creation and management
test_user_management() {
    log_test "User management functionality"

    local admin_token
    admin_token=$(get_authentik_admin_token)

    # Create test user
    local user_response
    user_response=$(curl -s -X POST "$AUTHENTIK_URL/api/v3/core/users/" \
        -H "Authorization: Bearer $admin_token" \
        -H "Content-Type: application/json" \
        -d '{
            "username": "testuser123",
            "name": "Test User",
            "email": "test@homelab.local"
        }')

    local user_pk
    user_pk=$(echo "$user_response" | jq -r '.pk')

    if [[ "$user_pk" != "null" ]] && [[ -n "$user_pk" ]]; then
        # Clean up test user
        curl -s -X DELETE "$AUTHENTIK_URL/api/v3/core/users/$user_pk/" \
            -H "Authorization: Bearer $admin_token" > /dev/null

        log_pass "User management functionality working"
    else
        log_fail "Failed to create test user"
    fi
}

# Test backup and configuration export
test_configuration_export() {
    log_test "Configuration export functionality"

    local admin_token
    admin_token=$(get_authentik_admin_token)

    # Test configuration export
    local export_response
    export_response=$(curl -s -H "Authorization: Bearer $admin_token" \
        "$AUTHENTIK_URL/api/v3/core/applications/?format=json")

    echo "$export_response" | jq -e '.results' > /dev/null

    log_pass "Configuration export is working"
}

# Helper function to get admin token
get_authentik_admin_token() {
    # In real implementation, this would authenticate and get a token
    # For testing purposes, we'll use a mock token or extract from setup
    local token_response
    token_response=$(curl -s -X POST "$AUTHENTIK_URL/api/v3/core/tokens/" \
        -H "Content-Type: application/json" \
        -d '{
            "identifier": "admin-api-token",
            "user": 1,
            "description": "Integration test token"
        }' 2>/dev/null || echo '{"key":"mock-token-for-testing"}')

    echo "$token_response" | jq -r '.key'
}

# Main test execution
run_sso_integration_tests() {
    log_info "Starting SSO Integration Tests"

    # Check if stack is running
    if ! docker compose -f stacks/sso/docker-compose.yml ps | grep -q "Up"; then
        log_warn "SSO stack not running, starting containers..."
        docker compose -f stacks/sso/docker-compose.yml up -d
        sleep 30  # Wait for services to initialize
    fi

    # Run tests
    test_sso_containers_running
    test_authentik_web_interface
    test_database_connectivity
    test_oidc_discovery
    test_forwardauth_middleware
    test_oidc_provider_creation
    test_application_creation
    test_authentication_flow
    test_integrated_services_config
    test_user_management
    test_configuration_export

    log_success "All SSO integration tests passed!"
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_sso_integration_tests
fi
