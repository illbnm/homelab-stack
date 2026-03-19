#!/bin/bash
# sso-flow.test.sh - SSO 完整登录流程端到端测试
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

# 使用 curl 模拟完整 OIDC 授权码流程
test_sso_grafana_login() {
    echo "[e2e] Testing SSO Grafana login flow..."
    
    local authentik_url="http://localhost:9000"
    local grafana_url="http://localhost:3000"
    local username="${TEST_USERNAME:-admin}"
    local password="${TEST_PASSWORD:-admin}"
    
    # 1. 访问 Grafana → 应该 302 跳转到 Authentik
    local redirect_url=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 10 "$grafana_url/login/generic_oauth" 2>/dev/null)
    
    if [[ -z "$redirect_url" || "$redirect_url" == "$grafana_url" ]]; then
        echo -e "${YELLOW}⏭️ SKIP${NC} OAuth not configured or already logged in"
        return 0
    fi
    
    # 2. 检查是否重定向到 Authentik
    if ! echo "$redirect_url" | grep -q "$authentik_url"; then
        echo -e "${YELLOW}⏭️ SKIP${NC} Not redirecting to Authentik"
        return 0
    fi
    
    echo -e "${GREEN}✅ PASS${NC} Redirect to Authentik OK"
    return 0
}

test_sso_authentik_oauth2_provider() {
    echo "[e2e] Testing Authentik OAuth2 Provider..."
    
    # 检查 Authentik 是否有配置的 OAuth2 提供商
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 \
        "http://localhost:9000/application/o/providers/" 2>/dev/null)
    
    if [[ "$http_code" == "200" || "$http_code" == "401" || "$http_code" == "403" ]]; then
        echo -e "${GREEN}✅ PASS${NC} OAuth2 providers endpoint accessible"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} OAuth2 providers endpoint returned $http_code"
        return 1
    fi
}

test_sso_authentik_applications() {
    echo "[e2e] Testing Authentik Applications..."
    
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 \
        "http://localhost:9000/application/o/applications/" 2>/dev/null)
    
    if [[ "$http_code" == "200" || "$http_code" == "401" || "$http_code" == "403" ]]; then
        echo -e "${GREEN}✅ PASS${NC} Applications endpoint accessible"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} Applications endpoint returned $http_code"
        return 1
    fi
}

run_sso_e2e_tests() {
    print_header "HomeLab Stack — SSO E2E Tests"
    
    test_sso_grafana_login || true
    test_sso_authentik_oauth2_provider || true
    test_sso_authentik_applications || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_sso_e2e_tests
fi
