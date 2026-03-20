#!/bin/bash

# Base stack integration tests
# Tests for Traefik, Portainer, and Watchtower

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/docker.sh"

STACK_NAME="base"
BASE_DIR="$(dirname "$0")/../../stacks/base"

test_stack_exists() {
    echo "Testing base stack configuration..."
    assert_file_exists "$BASE_DIR/docker-compose.yml"
    assert_file_exists "$BASE_DIR/.env.example"
}

test_traefik_container() {
    echo "Testing Traefik container..."
    assert_container_running "traefik"
    assert_container_healthy "traefik"

    # Test Traefik dashboard
    assert_http_200 "http://localhost:8080" "Traefik dashboard"

    # Check Traefik API
    assert_http_200 "http://localhost:8080/api/rawdata" "Traefik API"
}

test_portainer_container() {
    echo "Testing Portainer container..."
    assert_container_running "portainer"
    assert_container_healthy "portainer"

    # Test Portainer web interface
    assert_http_200 "http://localhost:9000" "Portainer web UI"

    # Check Portainer API is responding
    local response_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/api/status)
    if [ "$response_code" -eq 200 ] || [ "$response_code" -eq 401 ]; then
        echo "✓ Portainer API is responding"
    else
        echo "✗ Portainer API not responding (got $response_code)"
        return 1
    fi
}

test_watchtower_container() {
    echo "Testing Watchtower container..."
    assert_container_running "watchtower"

    # Watchtower doesn't have HTTP endpoint, check logs for startup
    local logs=$(docker logs watchtower --tail 10 2>&1)
    if echo "$logs" | grep -q "watchtower"; then
        echo "✓ Watchtower is logging activity"
    else
        echo "✗ Watchtower logs don't show expected content"
        return 1
    fi
}

test_traefik_proxy_config() {
    echo "Testing Traefik proxy configuration..."

    # Check if Traefik can see Docker containers
    local api_data=$(curl -s http://localhost:8080/api/rawdata)
    if echo "$api_data" | grep -q "docker"; then
        echo "✓ Traefik Docker provider is active"
    else
        echo "✗ Traefik Docker provider not found"
        return 1
    fi
}

test_network_connectivity() {
    echo "Testing network connectivity between services..."

    # Check if containers are on the same network
    local traefik_network=$(docker inspect traefik --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}')
    local portainer_network=$(docker inspect portainer --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}')

    if [ "$traefik_network" = "$portainer_network" ]; then
        echo "✓ Services are on the same Docker network"
    else
        echo "! Services may be on different networks (Traefik: $traefik_network, Portainer: $portainer_network)"
    fi
}

test_volume_mounts() {
    echo "Testing volume mounts..."

    # Check Traefik volume mounts
    docker exec traefik test -S /var/run/docker.sock
    assert_eq $? 0 "Traefik Docker socket mount"

    # Check Portainer data persistence
    docker exec portainer test -d /data
    assert_eq $? 0 "Portainer data directory"
}

run_base_tests() {
    echo "========================================="
    echo "Running Base Stack Tests"
    echo "========================================="

    local failed=0

    test_stack_exists || failed=$((failed + 1))
    test_traefik_container || failed=$((failed + 1))
    test_portainer_container || failed=$((failed + 1))
    test_watchtower_container || failed=$((failed + 1))
    test_traefik_proxy_config || failed=$((failed + 1))
    test_network_connectivity || failed=$((failed + 1))
    test_volume_mounts || failed=$((failed + 1))

    echo "========================================="
    if [ $failed -eq 0 ]; then
        echo "✓ All base stack tests passed!"
        return 0
    else
        echo "✗ $failed test(s) failed in base stack"
        return 1
    fi
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_base_tests
fi
