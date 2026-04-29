#!/usr/bin/env bash
assert_suite "base"

test_traefik_running() {
    assert_test "Traefik running"
    local state
    state=$(docker inspect -f '{{.State.Running}}' traefik 2>/dev/null || echo "false")
    if [[ "$state" == "true" ]]; then _pass; else _fail "traefik not running"; fi
}

test_traefik_healthy() {
    assert_container_healthy traefik 60
}

test_traefik_http() {
    assert_http_200 "http://localhost:8080/api/version" 10
}

test_portainer_running() {
    assert_container_running portainer
}

test_portainer_http() {
    assert_http_200 "http://localhost:9000" 10
}

test_watchtower_running() {
    assert_container_running watchtower
}

test_traefik_running
test_traefik_healthy
test_traefik_http
test_portainer_running
test_portainer_http
test_watchtower_running