#!/bin/bash
source "$(dirname "$0")/../lib/assert.sh"

test_traefik_running() {
    assert_container_running "traefik" "Traefik should be running"
}

test_portainer_running() {
    assert_container_running "portainer" "Portainer should be running"
    assert_http_200 "http://localhost:9000" "Portainer API should be accessible"
}

# Run tests
test_traefik_running
test_portainer_running
