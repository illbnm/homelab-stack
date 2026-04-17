#!/usr/bin/env bash
# tests/stacks/notifications.test.sh

describe "Notifications Stack (ntfy)"

it "ntfy container is running"
if container_exists "ntfy"; then
    assert_container_running "ntfy"
    it "ntfy HTTP responds"
    assert_http_200 "http://localhost:8081" 10
    it "ntfy is not crash-looping"
    assert_container_restarted "ntfy" 3
else
    skip "ntfy not found"
fi
