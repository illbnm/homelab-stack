#!/usr/bin/env bash
# tests/stacks/storage.test.sh — Storage stack (Nextcloud)

describe "Storage Stack"

it "Nextcloud container is running"
if container_exists "nextcloud"; then
    assert_container_running "nextcloud"
    it "Nextcloud is healthy"
    assert_container_healthy "nextcloud"
    it "Nextcloud status endpoint responds"
    assert_http_200 "http://localhost:8080/status.php" 10
    it "Nextcloud is not crash-looping"
    assert_container_restarted "nextcloud" 5
else
    skip "Nextcloud not found"
fi
