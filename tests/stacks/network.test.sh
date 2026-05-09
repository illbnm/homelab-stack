#!/usr/bin/env bash
assert_suite "network"

test_adguard_running() {
    assert_container_running adguardhome
}

test_adguard_status() {
    assert_http_200 "http://localhost:3000/control/status" 10
}

test_wireguard_running() {
    assert_container_running wg-easy
}

test_unbound_running() {
    assert_container_running unbound
}

test_adguard_running
test_adguard_status
test_wireguard_running
test_unbound_running