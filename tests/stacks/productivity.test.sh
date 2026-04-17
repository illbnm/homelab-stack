#!/usr/bin/env bash
# tests/stacks/productivity.test.sh

describe "Productivity Stack (Gitea)"

it "Gitea container is running"
if container_exists "gitea"; then
    assert_container_running "gitea"
    it "Gitea is healthy"
    assert_container_healthy "gitea"
    it "Gitea HTTP responds"
    assert_http_200 "http://localhost:3000" 10
    it "Gitea is not crash-looping"
    assert_container_restarted "gitea" 3
else
    skip "Gitea not found"
fi
