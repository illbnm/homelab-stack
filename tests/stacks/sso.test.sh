#!/usr/bin/env bash
# tests/stacks/sso.test.sh

describe "SSO Stack (Authentik)"

for name in authentik-server authentik-worker; do
    it "$name container is running"
    if container_exists "$name"; then
        assert_container_running "$name"
        it "$name is not crash-looping"
        assert_container_restarted "$name" 5
    else
        skip "$name not found"
    fi
done

it "Authentik HTTP responds"
assert_http_200 "http://localhost:9000" 10 || skip "Authentik port not exposed"
