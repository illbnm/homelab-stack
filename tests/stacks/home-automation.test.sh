#!/usr/bin/env bash
# tests/stacks/home-automation.test.sh

describe "Home Automation Stack (Home Assistant)"

it "Home Assistant container is running"
if container_exists "homeassistant"; then
    assert_container_running "homeassistant"
    it "Home Assistant HTTP responds"
    assert_http_200 "http://localhost:8123" 10
    it "Home Assistant is not crash-looping"
    assert_container_restarted "homeassistant" 3
else
    skip "Home Assistant not found"
fi
