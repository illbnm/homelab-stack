#!/usr/bin/env bash
# SSO流程端到端测试 - HomeLab Stack Integration Tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"

# 测试SSO登录流程
test_sso_grafana_login() {
    echo "测试 Grafana SSO 登录流程..."

    # 1. 访问 Grafana → 应该重定向到 Authentik
    local response
    response=$(curl -s -I "http://localhost:3000" 2>/dev/null)

    if echo "$response" | grep -q "302"; then
        echo -e "${GREEN}✅ PASS${NC}: Grafana正确重定向"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}: Grafana应该重定向到SSO"
        ((TESTS_FAILED++))
    fi
}

test_authentik_oidc_endpoint() {
    echo "测试 Authentik OIDC 端点..."

    if assert_http_200 "http://localhost:9000/application/o/grafana/.well-known/openid-configuration" 30; then
        echo -e "${GREEN}✅ PASS${NC}: Authentik OIDC配置可访问"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}: Authentik OIDC配置不可访问"
        ((TESTS_FAILED++))
    fi
}

# 主测试运行器
run_sso_e2e_tests() {
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║   Testing: SSO E2E Flow              ║"
    echo "╚══════════════════════════════════════╝"
    echo ""

    local start_time
    start_time=$(date +%s)

    test_authentik_oidc_endpoint || true
    test_sso_grafana_login || true

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    echo "──────────────────────────────────────"
    echo "SSO E2E Tests Complete"
    echo "Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"
    echo "Duration: ${duration}s"
    echo "──────────────────────────────────────"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_sso_e2e_tests
fi
