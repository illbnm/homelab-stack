#!/bin/bash

# Base stack container health tests
# Source the assertion library
source "${BASH_SOURCE%/*/*}/lib/assert.sh"

# Test Traefik
test_traefik_running() {
    assert_container_running "traefik" "Traefik container should be running"
}

test_traefik_healthy() {
    assert_container_healthy "traefik" "Traefik container should be healthy"
}

test_traefik_api() {
    assert_http_200 "http://localhost:9000/api/version" "Traefik API should return 200"
}

# Test Portainer
test_portainer_running() {
    assert_container_running "portainer" "Portainer container should be running"
}

test_portainer_healthy() {
    assert_container_healthy "portainer" "Portainer container should be healthy"
}

test_portainer_api() {
    assert_http_200 "http://localhost:9000/api/status" "Portainer API should return 200"
}

# Test Watchtower
test_watchtower_running() {
    assert_container_running "watchtower" "Watchtower container should be running"
}

# Run all tests
main() {
    test_traefik_running
    test_traefik_healthy
    test_traefik_api
    test_portainer_running
    test_portainer_healthy
    test_portainer_api
    test_watchtower_running
}

main "$@"