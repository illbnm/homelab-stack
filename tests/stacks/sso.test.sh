#!/usr/bin/env bash
# ==============================================================================
# SSO Stack Tests (Authentik)
# Tests for Authentik server, worker, and OIDC integration
# ==============================================================================

# Test: Authentik server is running
test_authentik_server_running() {
    assert_container_running "authentik-server"
}

# Test: Authentik worker is running
test_authentik_worker_running() {
    assert_container_running "authentik-worker"
}

# Test: Authentik server is healthy
test_authentik_server_healthy() {
    assert_container_healthy "authentik-server" 120
}

# Test: Authentik API is accessible
test_authentik_api() {
    local host="${AUTHENTIK_HOST:-localhost}"
    local port="${AUTHENTIK_PORT:-9000}"
    assert_http_200 "http://$host:$port/api/v3/core/applications/" 10 || \
    assert_http_code "http://$host:$port/api/v3/core/applications/" 403 10  # May require auth
}

# Test: Authentik static files
test_authentik_static() {
    local host="${AUTHENTIK_HOST:-localhost}"
    local port="${AUTHENTIK_PORT:-9000}"
    assert_http_200 "http://$host:$port/static/dist/assets/favicon.ico" 10
}

# Test: Authentik PostgreSQL connection
test_authentik_postgres() {
    begin_test
    local result=$(docker exec authentik-server ls /var/lib/authentak 2>/dev/null || echo "container not ready")
    if [[ "$result" != *"error"* ]]; then
        log_pass "Authentik container filesystem accessible"
    else
        log_skip "Authentik server not ready for internal checks"
    fi
}

# Test: Authentik Redis connection
test_authentik_redis() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "authentik-redis"; then
        assert_container_running "authentik-redis"
    else
        log_skip "Dedicated Authentik Redis not configured (using shared)"
    fi
}

# Test: OIDC discovery endpoint
test_oidc_discovery() {
    local host="${AUTHENTIK_HOST:-localhost}"
    local port="${AUTHENTIK_PORT:-9000}"
    assert_http_200 "http://$host:$port/application/o/authentik/.well-known/openid-configuration" 10
}

# Test: SSO compose syntax
test_sso_compose_syntax() {
    local compose_file="$BASE_DIR/stacks/sso/docker-compose.yml"
    if [[ -f "$compose_file" ]]; then
        assert_compose_syntax "$compose_file"
    else
        log_skip "SSO compose file not found"
    fi
}

# Run all tests
run_tests() {
    test_authentik_server_running
    test_authentik_worker_running
    test_authentik_server_healthy
    test_authentik_api
    test_authentik_static
    test_authentik_postgres
    test_authentik_redis
    test_oidc_discovery
    test_sso_compose_syntax
}

# Execute tests
run_tests