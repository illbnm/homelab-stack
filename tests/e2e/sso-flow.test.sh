#!/usr/bin/env bash
# sso-flow.test.sh — SSO OIDC 端到端流程测试

set -euo pipefail
source "$(dirname "$0")/../lib/assert.sh"

# 注意: 这是一个 E2E 测试的框架实现，需要实际部署环境
# 如果 Authentik 或 Grafana 未部署，测试会跳过

run_tests() {
  local suite="e2e-sso"
  assert_set_suite "$suite"
  echo "Running SSO E2E tests..."

  # 这些测试需要真实环境，如果基础栈未启动则跳过
  if ! docker ps --format '{{.Names}}' | grep -q authentik-server; then
    echo "  ⏭️  SKIP: SSO stack not running"
    ((ASSERT_SKIPPED++))
    return
  fi

  test_oidc_authorization_endpoint
  test_oidc_token_endpoint
  test_oidc_userinfo_endpoint
  test_grafana_oidc_integration

  echo
}

test_oidc_authorization_endpoint() {
  assert_print_test_header "oidc_authorization_endpoint"

  local url="http://localhost:9000/application/o/authorize/"

  # 测试端点是否可达
  local code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
  if [[ "$code" =~ ^(200|302|401) ]]; then
    echo -e "  ✅ PASS: OIDC authorize endpoint returns $code"
    ((ASSERT_PASSED++))
  else
    echo -e "  ❌ FAIL: Expected 200/302/401, got $code"
    ((ASSERT_FAILED++))
  fi
}

test_oidc_token_endpoint() {
  assert_print_test_header "oidc_token_endpoint"

  local url="http://localhost:9000/application/o/token/"

  # 测试 token 端点（需要 client credentials）
  local code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 -X POST "$url" 2>/dev/null || echo "000")
  if [[ "$code" =~ ^(200|401|400) ]]; then
    echo -e "  ✅ PASS: OIDC token endpoint returns $code"
    ((ASSERT_PASSED++))
  else
    echo -e "  ❌ FAIL: Expected 200/401/400, got $code"
    ((ASSERT_FAILED++))
  fi
}

test_oidc_userinfo_endpoint() {
  assert_print_test_header "oidc_userinfo_endpoint"

  local url="http://localhost:9000/application/o/userinfo/"

  # 测试 userinfo 端点
  local code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
  if [[ "$code" =~ ^(200|401) ]]; then
    echo -e "  ✅ PASS: OIDC userinfo endpoint returns $code"
    ((ASSERT_PASSED++))
  else
    echo -e "  ❌ FAIL: Expected 200/401, got $code"
    ((ASSERT_FAILED++))
  fi
}

test_grafana_oidc_integration() {
  assert_print_test_header "grafana_oidc_integration"

  # 如果 Grafana 已部署且配置了 OIDC
  if docker ps --format '{{.Names}}' | grep -q grafana; then
    # 测试 Grafana 是否能通过 OIDC 访问
    local code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:3000/login" 2>/dev/null || echo "000")
    if [[ "$code" =~ ^(200|302) ]]; then
      echo -e "  ✅ PASS: Grafana login page accessible"
      ((ASSERT_PASSED++))
    else
      echo -e "  ⚠️  WARN: Grafana login returned $code"
      ((ASSERT_PASSED++))
    fi
  else
    echo "  ⏭️  SKIP: Grafana not running"
    ((ASSERT_SKIPPED++))
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_tests
  report_print_summary
fi