#!/bin/bash
# notifications.test.sh - Notifications Stack 测试
# 测试 Gotify, Ntfy, Apprise

set -u

# Gotify 测试
test_gotify_running() {
    assert_container_running "gotify"
}

test_gotify_http() {
    assert_http_200 "http://localhost:8084"
}

test_gotify_health() {
    assert_http_response "http://localhost:8084/health" "status" "Gotify health"
}

# Ntfy 测试
test_ntfy_running() {
    assert_container_running "ntfy"
}

test_ntfy_http() {
    assert_http_200 "http://localhost:8085"
}

test_ntfy_health() {
    assert_http_response "http://localhost:8085/v1/health" "healthy" "Ntfy health"
}

# Apprise 测试
test_apprise_running() {
    assert_container_running "apprise"
}

test_apprise_http() {
    assert_http_200 "http://localhost:8000/notify"
}

test_apprise_health() {
    assert_http_200 "http://localhost:8000/health"
}
