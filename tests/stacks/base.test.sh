#!/bin/bash

# Base infrastructure stack tests
# Tests Traefik, Portainer, and Watchtower services

source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/docker.sh"

STACK_NAME="base"
COMPOSE_FILE="stacks/base/docker-compose.yml"

setup() {
    echo "Setting up base stack tests..."
    ensure_stack_running "$STACK_NAME" "$COMPOSE_FILE"
}

teardown() {
    echo "Base stack tests completed"
}

# Level 1 Tests - Container Health
test_traefik_running() {
    echo "Testing Traefik container health..."
    assert_container_running "traefik"
    assert_container_healthy "traefik"
    assert_container_not_restarting "traefik"
}

test_portainer_running() {
    echo "Testing Portainer container health..."
    assert_container_running "portainer"
    assert_container_healthy "portainer"
    assert_container_not_restarting "portainer"
}

test_watchtower_running() {
    echo "Testing Watchtower container health..."
    assert_container_running "watchtower"
    assert_container_not_restarting "watchtower"
    # Note: Watchtower may not have healthcheck configured
}

# Level 2 Tests - HTTP Endpoints
test_traefik_ping_endpoint() {
    echo "Testing Traefik /ping endpoint..."
    assert_http_200 "http://localhost:8080/ping"

    local response=$(curl -s "http://localhost:8080/ping")
    assert_eq "$response" "OK" "Traefik ping response"
}

test_traefik_dashboard() {
    echo "Testing Traefik dashboard accessibility..."
    assert_http_200 "http://localhost:8080/dashboard/"

    local content=$(curl -s "http://localhost:8080/dashboard/")
    assert_contains "$content" "Traefik" "Dashboard contains Traefik branding"
}

test_portainer_api_status() {
    echo "Testing Portainer API status..."
    assert_http_200 "http://localhost:9000/api/status"

    local status_json=$(curl -s "http://localhost:9000/api/status")
    assert_contains "$status_json" "Version" "Status response contains version info"
}

test_portainer_ui_accessible() {
    echo "Testing Portainer UI accessibility..."
    assert_http_200 "http://localhost:9000/"

    local ui_content=$(curl -s "http://localhost:9000/")
    assert_contains "$ui_content" "Portainer" "UI contains Portainer branding"
}

# Level 3 Tests - Service Integration
test_traefik_routes_configuration() {
    echo "Testing Traefik routes configuration..."

    # Check if Traefik API is accessible
    local api_response=$(curl -s "http://localhost:8080/api/http/routers")
    assert_not_empty "$api_response" "Traefik API returns router configuration"

    # Verify Portainer route is configured
    assert_contains "$api_response" "portainer" "Portainer route configured in Traefik"
}

test_traefik_docker_provider() {
    echo "Testing Traefik Docker provider connectivity..."

    local providers_response=$(curl -s "http://localhost:8080/api/providers")
    assert_contains "$providers_response" "docker" "Docker provider is active"
}

test_watchtower_docker_access() {
    echo "Testing Watchtower Docker socket access..."

    # Check watchtower logs for successful Docker API connection
    local logs=$(docker logs watchtower 2>&1 | tail -20)
    assert_not_contains "$logs" "permission denied" "Watchtower has Docker socket access"
    assert_not_contains "$logs" "connection refused" "Watchtower can connect to Docker daemon"
}

test_base_network_connectivity() {
    echo "Testing base network connectivity..."

    # Verify containers are on the same network
    local traefik_networks=$(docker inspect traefik --format='{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}')
    local portainer_networks=$(docker inspect portainer --format='{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}')

    assert_contains "$traefik_networks" "homelab" "Traefik connected to homelab network"
    assert_contains "$portainer_networks" "homelab" "Portainer connected to homelab network"
}

test_base_volumes_mounted() {
    echo "Testing base stack volume mounts..."

    # Check Traefik volumes
    local traefik_mounts=$(docker inspect traefik --format='{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}')
    assert_contains "$traefik_mounts" "/var/run/docker.sock" "Traefik has Docker socket mounted"

    # Check Portainer volumes
    local portainer_mounts=$(docker inspect portainer --format='{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}')
    assert_contains "$portainer_mounts" "/var/run/docker.sock" "Portainer has Docker socket mounted"
    assert_contains "$portainer_mounts" "portainer_data" "Portainer has data volume mounted"

    # Check Watchtower volumes
    local watchtower_mounts=$(docker inspect watchtower --format='{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}')
    assert_contains "$watchtower_mounts" "/var/run/docker.sock" "Watchtower has Docker socket mounted"
}

# Run all tests
run_tests() {
    setup

    echo "=== Level 1: Container Health Tests ==="
    test_traefik_running
    test_portainer_running
    test_watchtower_running

    echo "=== Level 2: HTTP Endpoint Tests ==="
    test_traefik_ping_endpoint
    test_traefik_dashboard
    test_portainer_api_status
    test_portainer_ui_accessible

    echo "=== Level 3: Service Integration Tests ==="
    test_traefik_routes_configuration
    test_traefik_docker_provider
    test_watchtower_docker_access
    test_base_network_connectivity
    test_base_volumes_mounted

    teardown
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
