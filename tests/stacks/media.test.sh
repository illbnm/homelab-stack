#!/usr/bin/env bash
# tests/stacks/media.test.sh — Media stack (Jellyfin)

describe "Media Stack"

it "Jellyfin container is running"
if container_exists "jellyfin"; then
    assert_container_running "jellyfin"
    it "Jellyfin is healthy"
    assert_container_healthy "jellyfin"
    it "Jellyfin HTTP responds"
    assert_http_200 "http://localhost:8096" 10
    it "Jellyfin is not crash-looping"
    assert_container_restarted "jellyfin" 5
else
    skip "Jellyfin not found"
fi
