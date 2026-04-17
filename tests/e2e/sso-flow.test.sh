#!/usr/bin/env bash
# tests/e2e/sso-flow.test.sh — SSO end-to-end flow

describe "E2E: SSO Login Flow"

it "Authentik server is running"
if container_exists "authentik-server"; then
    assert_container_running "authentik-server"
    it "Authentik login page loads"
    assert_http_200 "http://localhost:9000/if/flow/default-authentication-flow/" 15
    it "Authentik API is accessible"
    assert_http_200 "http://localhost:9000/api/v3/core/config/" 10
else
    skip "Authentik not found — skipping SSO E2E tests"
fi
