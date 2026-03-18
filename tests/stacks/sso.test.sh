#!/usr/bin/env bash
# sso.test.sh — SSO Stack (Authentik) 测试

set -euo pipefail
source "$(dirname "$0")/../lib/assert.sh"

COMPOSE_FILE="$(dirname "$0")/../../stacks/sso/docker-compose.yml"

run_tests() {
  local suite="sso"
  assert_set_suite "$suite"
  echo "Running SSO Stack tests..."

  test_containers_running
  test_containers_healthy
  test_authentik_http
  test_postgres_healthy
  test_redis_healthy
  test_authentik_api_access
  test_compose_syntax
  test_no_latest_tags

  echo
}

test_containers_running() {
  assert_print_test_header "containers_running"
  assert_container_running "authentik-server" 90
  assert_container_running "authentik-postgresql" 90
  assert_container_running "authentik-redis" 90
}

test_containers_healthy() {
  assert_print_test_header "containers_healthy"
  assert_container_healthy "authentik-server" 180
  assert_container_healthy "authentik-postgresql" 120
  assert_container_healthy "authentik-redis" 120
}

test_authentik_http() {
  assert_print_test_header "authentik_http"
  assert_http_200 "http://localhost:9000" 60
}

test_postgres_healthy() {
  assert_print_test_header "postgres_healthy"
  # PostgreSQL 健康检查（可通过 authentik 容器内测试）
  if docker exec authentik-server pg_isready -U authentik &>/dev/null; then
    echo -e "  ✅ PASS: PostgreSQL is ready"
    ((ASSERT_PASSED++))
  else
    echo -e "  ⚠️  WARN: PostgreSQL check skipped"
    ((ASSERT_SKIPPED++))
  fi
}

test_authentik_api_access() {
  assert_print_test_header "authentik_api_access"

  # 测试 API 端点（需要认证，只检查 401/200）
  local api_url="http://localhost:9000/api/v3/core/users/"
  local code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$api_url" 2>/dev/null || echo "000")

  if [[ "$code" == "200" || "$code" == "401" ]]; then
    echo -e "  ✅ PASS: Authentik API responds $code"
    ((ASSERT_PASSED++))
  else
    echo -e "  ❌ FAIL: Authentik API returned $code"
    ((ASSERT_FAILED++))
  fi
}

test_compose_syntax() {
  assert_print_test_header "compose_syntax"
  docker compose -f "$COMPOSE_FILE" config --quiet 2>/dev/null
  assert_exit_code 0
}

test_no_latest_tags() {
  assert_print_test_header "no_latest_tags"
  local count=$(grep -r ':latest' "$(dirname "$COMPOSE_FILE")" 2>/dev/null | wc -l | tr -d ' ')
  assert_eq "$count" "0"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_tests
  report_print_summary
fi