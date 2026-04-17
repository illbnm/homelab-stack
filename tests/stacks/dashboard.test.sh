#!/usr/bin/env bash
# tests/stacks/dashboard.test.sh

describe "Dashboard Stack (Homarr)"

it "Homarr container is running"
if container_exists "homarr"; then
    assert_container_running "homarr"
    it "Homarr is healthy"
    assert_container_healthy "homarr"
    it "Homarr HTTP responds"
    assert_http_200 "http://localhost:7575" 10
else
    skip "Homarr not found"
fi
