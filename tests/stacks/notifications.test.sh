#!/usr/bin/env bash
assert_suite "notifications"

test_ntfy_running() {
    assert_container_running ntfy
}

test_ntfy_healthy() {
    assert_http_200 "http://localhost:80/v1/health" 10
}

test_gotify_running() {
    assert_container_running gotify
}

test_alertmanager_running() {
    assert_container_running alertmanager
}

test_alertmanager_healthy() {
    assert_http_200 "http://localhost:9093/-/healthy" 10
}

test_ntfy_running
test_ntfy_healthy
test_gotify_running
test_alertmanager_running
test_alertmanager_healthy