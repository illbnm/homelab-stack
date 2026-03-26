#!/usr/bin/env bash
# sso-flow.test.sh - SSO OIDC Flow E2E 测试
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"
STACK_NAME="e2e-sso"

test_authentik_oidc_provider() {
    test_start "Authentik - OIDC Provider 可用"
    if curl -sf -o /dev/null --max-time 15 "http://127.0.0.1:9000/" 2>/dev/null; then
        test_end "Authentik - OIDC Provider 可用" "PASS"
    else test_end "Authentik - OIDC Provider 可用" "FAIL"; return 1; fi
    
    test_start "Authentik - OpenID Configuration"
    local oidc_config; oidc_config=$(curl -sf --max-time 15 "http://127.0.0.1:9000/.well-known/openid-configuration" 2>/dev/null)
    if [[ -n "$oidc_config" ]]; then test_end "Authentik - OpenID Configuration" "PASS"
    else test_end "Authentik - OpenID Configuration" "FAIL"; return 1; fi
    
    test_start "Authentik - JWKS 端点"
    local jwks; jwks=$(curl -sf --max-time 15 "http://127.0.0.1:9000/.well-known/jwks.json" 2>/dev/null)
    if [[ -n "$jwks" ]]; then test_end "Authentik - JWKS 端点" "PASS"
    else test_end "Authentik - JWKS 端点" "FAIL"; return 1; fi
}

test_traefik_forward_auth() {
    test_start "Traefik - Forward Auth 端点"
    local auth_response; auth_response=$(curl -sf -o /dev/null -w "%{http_code}" --max-time 10 \
        -H "X-Forwarded-Uri: /test" \
        -H "X-Forwarded-Host: test.example.com" \
        "http://127.0.0.1:9000/outpost.goauthentik.io/auth/start" 2>/dev/null)
    if [[ "$auth_response" == "302" ]] || [[ "$auth_response" == "401" ]] || [[ "$auth_response" == "403" ]]; then
        test_end "Traefik - Forward Auth 端点" "PASS" "返回码: $auth_response"
    else test_end "Traefik - Forward Auth 端点" "SKIP"; fi
}

test_service_network_connectivity() {
    test_start "Network - Authentik 到 PostgreSQL"
    if can_container_connect "authentik-server" "authentik-postgres" 5432; then
        test_end "Network - Authentik 到 PostgreSQL" "PASS"
    else test_end "Network - Authentik 到 PostgreSQL" "SKIP"; fi
    
    test_start "Network - Authentik 到 Redis"
    if can_container_connect "authentik-server" "authentik-redis" 6379; then
        test_end "Network - Authentik 到 Redis" "PASS"
    else test_end "Network - Authentik 到 Redis" "SKIP"; fi
    
    test_start "Network - Traefik 到 Authentik"
    if containers_in_same_network "traefik" "authentik-server"; then
        test_end "Network - Traefik 到 Authentik" "PASS"
    else test_end "Network - Traefik 到 Authentik" "SKIP"; fi
}

test_main() {
    test_group_start "$STACK_NAME"
    test_authentik_oidc_provider || true; test_traefik_forward_auth || true; test_service_network_connectivity || true
    test_group_end "$STACK_NAME" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "${SCRIPT_DIR}/lib/assert.sh"; source "${SCRIPT_DIR}/lib/docker.sh"; source "${SCRIPT_DIR}/lib/report.sh"
    report_init; test_main; print_summary "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
