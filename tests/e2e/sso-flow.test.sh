#!/bin/bash

# SSO End-to-End Authentication Flow Test
# Tests complete user authentication lifecycle with Authentik

set -euo pipefail

# Source test libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/assert.sh"
source "${SCRIPT_DIR}/../lib/docker.sh"
source "${SCRIPT_DIR}/../lib/report.sh"

# Test configuration
AUTHENTIK_URL="${AUTHENTIK_URL:-http://localhost:9000}"
AUTHENTIK_ADMIN_USER="${AUTHENTIK_ADMIN_USER:-akadmin}"
AUTHENTIK_ADMIN_PASS="${AUTHENTIK_ADMIN_PASS:-password123}"
TEST_USER_EMAIL="testuser@homelab.local"
TEST_USER_PASSWORD="TestPass2024!"
TEST_APPLICATION_SLUG="homelab-app"

# Temporary files for test data
TEMP_DIR=$(mktemp -d)
COOKIE_JAR="${TEMP_DIR}/cookies.txt"
ADMIN_TOKEN_FILE="${TEMP_DIR}/admin_token.txt"
USER_TOKEN_FILE="${TEMP_DIR}/user_token.txt"

cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

test_authentik_services_running() {
    report_test_start "Authentik services are running"

    assert_container_running "authentik-server"
    assert_container_running "authentik-worker"
    assert_container_running "authentik-redis"
    assert_container_running "authentik-postgres"

    # Wait for services to be ready
    sleep 10
    assert_http_200 "${AUTHENTIK_URL}/if/flow/initial-setup/"

    report_test_pass "Authentik services are healthy"
}

test_admin_authentication() {
    report_test_start "Admin authentication"

    # Get admin authentication token
    local response=$(curl -s -X POST "${AUTHENTIK_URL}/api/v3/flows/executor/default-authentication-flow/" \
        -H "Content-Type: application/json" \
        -c "${COOKIE_JAR}" \
        -d "{
            \"uid_field\": \"${AUTHENTIK_ADMIN_USER}\",
            \"password\": \"${AUTHENTIK_ADMIN_PASS}\"
        }")

    # Extract session token from response
    local token=$(echo "${response}" | jq -r '.token // empty')
    if [[ -n "${token}" && "${token}" != "null" ]]; then
        echo "${token}" > "${ADMIN_TOKEN_FILE}"
        report_test_pass "Admin authentication successful"
    else
        report_test_fail "Admin authentication failed"
        return 1
    fi
}

test_user_creation() {
    report_test_start "Test user creation"

    local admin_token
    admin_token=$(cat "${ADMIN_TOKEN_FILE}")

    # Create test user via API
    local user_response=$(curl -s -X POST "${AUTHENTIK_URL}/api/v3/core/users/" \
        -H "Authorization: Bearer ${admin_token}" \
        -H "Content-Type: application/json" \
        -b "${COOKIE_JAR}" \
        -d "{
            \"username\": \"testuser\",
            \"email\": \"${TEST_USER_EMAIL}\",
            \"name\": \"Test User\",
            \"is_active\": true,
            \"groups\": []
        }")

    local user_pk=$(echo "${user_response}" | jq -r '.pk // empty')
    if [[ -n "${user_pk}" && "${user_pk}" != "null" ]]; then
        # Set user password
        curl -s -X POST "${AUTHENTIK_URL}/api/v3/core/users/${user_pk}/set_password/" \
            -H "Authorization: Bearer ${admin_token}" \
            -H "Content-Type: application/json" \
            -b "${COOKIE_JAR}" \
            -d "{\"password\": \"${TEST_USER_PASSWORD}\"}"

        report_test_pass "Test user created successfully"
    else
        report_test_fail "Failed to create test user"
        return 1
    fi
}

test_application_configuration() {
    report_test_start "Application configuration"

    local admin_token
    admin_token=$(cat "${ADMIN_TOKEN_FILE}")

    # Create OAuth2 provider
    local provider_response=$(curl -s -X POST "${AUTHENTIK_URL}/api/v3/providers/oauth2/" \
        -H "Authorization: Bearer ${admin_token}" \
        -H "Content-Type: application/json" \
        -b "${COOKIE_JAR}" \
        -d "{
            \"name\": \"Homelab OAuth2 Provider\",
            \"client_type\": \"confidential\",
            \"redirect_uris\": \"${AUTHENTIK_URL}/source/oauth/callback/homelab/\",
            \"signing_key\": null
        }")

    local provider_pk=$(echo "${provider_response}" | jq -r '.pk // empty')
    local client_id=$(echo "${provider_response}" | jq -r '.client_id // empty')

    if [[ -n "${provider_pk}" && "${provider_pk}" != "null" ]]; then
        # Create application
        local app_response=$(curl -s -X POST "${AUTHENTIK_URL}/api/v3/core/applications/" \
            -H "Authorization: Bearer ${admin_token}" \
            -H "Content-Type: application/json" \
            -b "${COOKIE_JAR}" \
            -d "{
                \"name\": \"Homelab Application\",
                \"slug\": \"${TEST_APPLICATION_SLUG}\",
                \"provider\": ${provider_pk}
            }")

        local app_slug=$(echo "${app_response}" | jq -r '.slug // empty')
        if [[ "${app_slug}" == "${TEST_APPLICATION_SLUG}" ]]; then
            report_test_pass "Application configured successfully"
        else
            report_test_fail "Failed to configure application"
            return 1
        fi
    else
        report_test_fail "Failed to create OAuth2 provider"
        return 1
    fi
}

test_user_login_flow() {
    report_test_start "User login flow"

    # Clear cookies for user session
    rm -f "${COOKIE_JAR}"

    # Initiate login flow
    local flow_response=$(curl -s -X GET "${AUTHENTIK_URL}/application/o/${TEST_APPLICATION_SLUG}/" \
        -c "${COOKIE_JAR}" \
        -L)

    # Submit credentials
    local auth_response=$(curl -s -X POST "${AUTHENTIK_URL}/api/v3/flows/executor/default-authentication-flow/" \
        -H "Content-Type: application/json" \
        -c "${COOKIE_JAR}" \
        -b "${COOKIE_JAR}" \
        -d "{
            \"uid_field\": \"testuser\",
            \"password\": \"${TEST_USER_PASSWORD}\"
        }")

    # Check if authentication was successful
    if echo "${auth_response}" | jq -e '.redirect // empty' > /dev/null; then
        report_test_pass "User login flow successful"
    else
        report_test_fail "User login flow failed"
        return 1
    fi
}

test_token_validation() {
    report_test_start "Token validation"

    # Get user info with session
    local userinfo_response=$(curl -s -X GET "${AUTHENTIK_URL}/application/o/userinfo/" \
        -H "Content-Type: application/json" \
        -b "${COOKIE_JAR}")

    local username=$(echo "${userinfo_response}" | jq -r '.preferred_username // empty')
    local email=$(echo "${userinfo_response}" | jq -r '.email // empty')

    if [[ "${username}" == "testuser" && "${email}" == "${TEST_USER_EMAIL}" ]]; then
        report_test_pass "Token validation successful"
    else
        report_test_fail "Token validation failed"
        return 1
    fi
}

test_protected_resource_access() {
    report_test_start "Protected resource access"

    # Test access to protected application endpoint
    local protected_response=$(curl -s -X GET "${AUTHENTIK_URL}/application/o/${TEST_APPLICATION_SLUG}/userinfo/" \
        -b "${COOKIE_JAR}")

    local response_code=$(curl -s -o /dev/null -w "%{http_code}" -X GET "${AUTHENTIK_URL}/application/o/${TEST_APPLICATION_SLUG}/userinfo/" \
        -b "${COOKIE_JAR}")

    if [[ "${response_code}" == "200" ]]; then
        report_test_pass "Protected resource access granted"
    else
        report_test_fail "Protected resource access denied (HTTP ${response_code})"
        return 1
    fi
}

test_logout_flow() {
    report_test_start "Logout flow"

    # Perform logout
    local logout_response=$(curl -s -X GET "${AUTHENTIK_URL}/if/flow/default-invalidation-flow/" \
        -b "${COOKIE_JAR}" \
        -c "${COOKIE_JAR}")

    # Verify session is invalidated
    local verification_response=$(curl -s -o /dev/null -w "%{http_code}" \
        -X GET "${AUTHENTIK_URL}/application/o/userinfo/" \
        -b "${COOKIE_JAR}")

    if [[ "${verification_response}" == "401" || "${verification_response}" == "403" ]]; then
        report_test_pass "Logout flow successful"
    else
        report_test_fail "Logout flow failed - session still active"
        return 1
    fi
}

test_user_cleanup() {
    report_test_start "Test user cleanup"

    local admin_token
    admin_token=$(cat "${ADMIN_TOKEN_FILE}")

    # Find and delete test user
    local users_response=$(curl -s -X GET "${AUTHENTIK_URL}/api/v3/core/users/?username=testuser" \
        -H "Authorization: Bearer ${admin_token}" \
        -b "${COOKIE_JAR}")

    local user_pk=$(echo "${users_response}" | jq -r '.results[0].pk // empty')

    if [[ -n "${user_pk}" && "${user_pk}" != "null" ]]; then
        curl -s -X DELETE "${AUTHENTIK_URL}/api/v3/core/users/${user_pk}/" \
            -H "Authorization: Bearer ${admin_token}" \
            -b "${COOKIE_JAR}"

        report_test_pass "Test user cleaned up"
    else
        report_test_pass "Test user already removed"
    fi
}

# Main test execution
main() {
    report_suite_start "SSO End-to-End Authentication Flow"

    test_authentik_services_running
    test_admin_authentication
    test_user_creation
    test_application_configuration
    test_user_login_flow
    test_token_validation
    test_protected_resource_access
    test_logout_flow
    test_user_cleanup

    report_suite_end
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
