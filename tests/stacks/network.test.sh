#!/bin/bash
# network.test.sh - Network Stack 测试
# 测试 AdGuard Home, WireGuard Easy, Nginx Proxy Manager

set -u

# AdGuard Home 测试
test_adguard_running() {
    assert_container_running "adguard"
}

test_adguard_http() {
    assert_http_response "http://localhost:3000/control/status" "version" "AdGuard status"
}

# WireGuard Easy 测试
test_wireguard_running() {
    assert_container_running "wireguard"
}

test_wireguard_http() {
    assert_http_200 "http://localhost:51821"
}

# Nginx Proxy Manager 测试
test_npm_running() {
    assert_container_running "npm"
}

test_npm_http() {
    assert_http_200 "http://localhost:81"
}
