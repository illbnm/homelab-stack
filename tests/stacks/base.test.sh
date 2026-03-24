#!/usr/bin/env bash
# ==============================================================================
# Base Infrastructure Stack Tests
# Tests for Traefik, Portainer, Watchtower, and Socket Proxy
# ==============================================================================

# Test: Traefik container is running
test_traefik_running() {
    assert_container_running "traefik"
}

# Test: Traefik is healthy
test_traefik_healthy() {
    assert_container_healthy "traefik" 60
}

# Test: Traefik HTTP port (80) is accessible
test_traefik_http_port() {
    local code=$(curl -sf -o /dev/null -w '%{http_code}' \
        --connect-timeout 5 --max-time 10 "http://localhost:80" 2>/dev/null || echo "000")
    # Expect 301 redirect to HTTPS or 404 (no default route)
    if [[ "$code" =~ ^(301|308|404)$ ]]; then
        log_pass "Traefik HTTP port 80 responds with $code"
    else
        log_fail "Traefik HTTP port 80 - unexpected response: $code"
    fi
}

# Test: Traefik HTTPS port (443) is accessible
test_traefik_https_port() {
    local code=$(curl -sfk -o /dev/null -w '%{http_code}' \
        --connect-timeout 5 --max-time 10 "https://localhost:443" 2>/dev/null || echo "000")
    # Expect 404 (no default route) or 200
    if [[ "$code" =~ ^(200|404)$ ]]; then
        log_pass "Traefik HTTPS port 443 responds with $code"
    else
        log_fail "Traefik HTTPS port 443 - unexpected response: $code"
    fi
}

# Test: Traefik API/ping endpoint
test_traefik_ping() {
    assert_http_200 "http://localhost:8080/ping" 10
}

# Test: Traefik proxy network exists
test_traefik_proxy_network() {
    begin_test
    if docker network inspect proxy >/dev/null 2>&1; then
        log_pass "Proxy network exists"
    else
        log_fail "Proxy network not found"
    fi
}

# Test: Portainer container is running
test_portainer_running() {
    assert_container_running "portainer"
}

# Test: Portainer is healthy
test_portainer_healthy() {
    assert_container_healthy "portainer" 60
}

# Test: Portainer API status endpoint
test_portainer_api() {
    assert_http_code "http://localhost:9000/api/status" 200 10 || \
    assert_http_code "http://localhost:9000/api/status" 401 10  # May require auth
}

# Test: Watchtower container is running
test_watchtower_running() {
    assert_container_running "watchtower"
}

# Test: Socket Proxy container (if configured)
test_socket_proxy_running() {
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "docker-socket-proxy"; then
        assert_container_running "docker-socket-proxy"
        assert_container_healthy "docker-socket-proxy" 30
    else
        log_skip "Socket Proxy not configured"
    fi
}

# Test: Docker Compose syntax for base stack
test_base_compose_syntax() {
    local compose_file="$BASE_DIR/stacks/base/docker-compose.yml"
    if [[ -f "$compose_file" ]]; then
        assert_compose_syntax "$compose_file"
    else
        log_skip "Base compose file not found"
    fi
}

# Test: No :latest image tags
test_no_latest_tags() {
    assert_no_latest_tags "$BASE_DIR/stacks/base"
}

# Test: All required environment variables
test_required_env_vars() {
    begin_test
    local missing=""
    
    [[ -z "${DOMAIN:-}" ]] && missing+="DOMAIN "
    [[ -z "${ACME_EMAIL:-}" ]] && missing+="ACME_EMAIL "
    [[ -z "${TZ:-}" ]] && missing+="TZ "
    
    if [[ -z "$missing" ]]; then
        log_pass "All required environment variables set"
    else
        log_fail "Missing environment variables:$missing"
    fi
}

# Run all tests
run_tests() {
    test_traefik_running
    test_traefik_healthy
    test_traefik_http_port
    test_traefik_https_port
    test_traefik_ping
    test_traefik_proxy_network
    test_portainer_running
    test_portainer_healthy
    test_portainer_api
    test_watchtower_running
    test_socket_proxy_running
    test_base_compose_syntax
    test_no_latest_tags
    test_required_env_vars
}

# Execute tests
run_tests