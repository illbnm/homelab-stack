#!/usr/bin/env bash
assert_suite "e2e/sso-flow"

test_sso_grafana_login() {
    assert_test "Grafana OIDC redirect to Authentik"
    local code
    code=$(curl -sS -o /dev/null -w '%{http_code}' -L --max-time 10 "http://localhost:3000/login/generic_oauth" 2>/dev/null || echo "000")
    if [[ "$code" == "302" || "$code" == "200" ]]; then
        _pass
    else
        _fail "Expected 302 or 200, got $code"
    fi
}

test_sso_grafana_login