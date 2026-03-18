#!/usr/bin/env bash
# notifications.test.sh — Notifications Stack 测试

set -euo pipefail
source "$(dirname "$0")/../lib/assert.sh"

COMPOSE_FILE="$(dirname "$0")/../../stacks/notifications/docker-compose.yml"

run_tests() {
  local suite="notifications"
  assert_set_suite "$suite"
  echo "Running Notifications Stack tests..."

  test_containers_running
  test_containers_healthy
  test_ntfy_http
  test_gotify_http
  test_alertmanager_http
  test_compose_syntax
  test_no_latest_tags

  echo
}

test_containers_running() {
  assert_print_test_header "containers_running"
  assert_container_running "ntfy" 60
  assert_container_running "gotify" 60
  assert_container_running "alertmanager" 60
}

test_containers_healthy() {
  assert_print_test_header "containers_healthy"
  assert_container_healthy "ntfy" 90
  assert_container_healthy "gotify" 90
  assert_container_healthy "alertmanager" 90
}

test_ntfy_http() {
  assert_print_test_header "ntfy_http"
  assert_http_200 "http://localhost:80/api/v1/health" 30  # 或实际端口
}

test_gotify_http() {
  assert_print_test_header "gotify_http"
  assert_http_200 "http://localhost:80" 30
}

test_alertmanager_http() {
  assert_print_test_header "alertmanager_http"
  assert_http_200 "http://alertmanager:9093/-/healthy" 30
}

test_compose_syntax() {
  assert_print_test_header "compose_syntax"
  docker compose -f "$COMPOSE_FILE" config --quiet 2>/dev/null
  assert_exit_code 0 "Compose config valid"
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