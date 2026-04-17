#!/usr/bin/env bash
# tests/stacks/network.test.sh

describe "Network Stack (AdGuard Home)"

it "AdGuard Home container is running"
if container_exists "adguardhome"; then
    assert_container_running "adguardhome"
    it "AdGuard HTTP responds"
    assert_http_200 "http://localhost:3000" 10
    it "AdGuard is not crash-looping"
    assert_container_restarted "adguardhome" 3
else
    skip "AdGuard Home not found"
fi
