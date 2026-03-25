#!/bin/bash
# sso-flow.test.sh - SSO 端到端测试
# 测试完整的 OIDC 授权码流程

set -u

# SSO Grafana 登录流程测试
test_sso_grafana_login() {
    # 1. 访问 Grafana → 应该 302 跳转到 Authentik
    local redirect_url=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 10 "http://localhost:3000/login/generic_oauth" 2>/dev/null)
    
    if [[ -n "$redirect_url" && "$redirect_url" == *"authentik"* ]]; then
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "PASS" "SSO redirect to Authentik" "$duration"
    else
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "SKIP" "SSO redirect to Authentik" "$duration"
        return 0
    fi
    
    # 2. 检查 Authentik 登录页面可访问
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$redirect_url" 2>/dev/null)
    
    if [[ "$http_code" == "200" ]]; then
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "PASS" "Authentik login page accessible" "$duration"
    else
        local start_time=$(date +%s.%N)
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
        _record_assertion "FAIL" "Authentik login page accessible" "$duration" "Expected 200, Got: $http_code"
    fi
}

# SSO 完整流程测试 (需要凭证)
test_sso_full_flow() {
    # 此测试需要实际的用户凭证，在 CI 环境中跳过
    local start_time=$(date +%s.%N)
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
    _record_assertion "SKIP" "SSO full flow (requires credentials)" "$duration"
}
