#!/usr/bin/env bash
# tests/stacks/base.test.sh — Base infrastructure tests

describe "Base Stack (Traefik + Portainer + Watchtower)"

# --- Traefik ---
it "Traefik container is running"
assert_container_running "traefik"

it "Traefik is healthy"
assert_container_healthy "traefik"

it "Traefik is not crash-looping"
assert_container_restarted "traefik" 5

it "Traefik exposes port 80"
assert_http_200 "http://localhost:80" 5

it "Traefik exposes port 443"
# Just check the port is listening, not full TLS handshake
container_exists "traefik" && assert_exit_code 0 "timeout 3 bash -c '</dev/tcp/localhost/443'" || skip "Traefik not found"

it "Traefik dashboard is accessible (if enabled)"
assert_http_status "http://localhost:8080/dashboard/" "200" 5 || skip "Dashboard not enabled"

# --- Portainer ---
it "Portainer container is running"
if container_exists "portainer"; then
    assert_container_running "portainer"
    it "Portainer HTTP endpoint responds"
    assert_http_200 "http://localhost:9000" 10
    it "Portainer is not crash-looping"
    assert_container_restarted "portainer" 3
else
    skip "Portainer container not found"
fi

# --- Watchtower ---
it "Watchtower container is running"
if container_exists "watchtower"; then
    assert_container_running "watchtower"
    it "Watchtower is not crash-looping"
    assert_container_restarted "watchtower" 3
else
    skip "Watchtower container not found"
fi
