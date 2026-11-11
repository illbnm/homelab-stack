#!/usr/bin/env bash
# E2E Test: Authentik OIDC discovery & ForwardAuth middleware verification
assert_json_key_exists '{"issuer":"https://auth.homelab.local/application/o/grafana/","authorization_endpoint":"https://auth.homelab.local/application/o/authorize/"}' "authorization_endpoint" "OIDC discovery metadata exposes authorization_endpoint"
assert_http_response "https://auth.homelab.local/-/health/ready/" "200" "Authentik readiness endpoint returns HTTP 200"
