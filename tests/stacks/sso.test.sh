#!/usr/bin/env bash
assert_suite "sso"

test_authentik_server_running() {
    assert_container_running authentik-server
}

test_authentik_worker_running() {
    assert_container_running authentik-worker
}

test_authentik_api() {
    assert_http_200 "http://localhost:9000/api/v3/core/users/?page_size=1" 15
}

test_authentik_server_running
test_authentik_worker_running
test_authentik_api