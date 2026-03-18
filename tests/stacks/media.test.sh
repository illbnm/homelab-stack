#!/usr/bin/env bash
# media.test.sh — Media Stack 测试

set -euo pipefail
source "$(dirname "$0")/../lib/assert.sh"

COMPOSE_FILE="$(dirname "$0")/../../stacks/media/docker-compose.yml"

run_tests() {
  local suite="media"
  assert_set_suite "$suite"
  echo "Running Media Stack tests..."

  test_containers_running
  test_containers_healthy
  test_jellyfin_http
  test_sonarr_http
  test_radarr_http
  test_prowlarr_http
  test_qbittorrent_http
  test_jellyseerr_http
  test_compose_syntax
  test_no_latest_tags

  echo
}

test_containers_running() {
  assert_print_test_header "containers_running"
  for svc in jellyfin sonarr radarr prowlarr qbittorrent jellyseerr; do
    assert_container_running "$svc" 90
  done
}

test_containers_healthy() {
  assert_print_test_header "containers_healthy"
  for svc in jellyfin sonarr radarr prowlarr qbittorrent jellyseerr; do
    assert_container_healthy "$svc" 120
  done
}

test_jellyfin_http() {
  assert_print_test_header "jellyfin_http"
  assert_http_200 "http://localhost:8096" 30
}

test_sonarr_http() {
  assert_print_test_header "sonarr_http"
  assert_http_200 "http://localhost:8989/api/v3/system/status" 30
}

test_radarr_http() {
  assert_print_test_header "radarr_http"
  assert_http_200 "http://localhost:7878/api/v3/system/status" 30
}

test_prowlarr_http() {
  assert_print_test_header "prowlarr_http"
  assert_http_200 "http://localhost:9696/api/v1/system/status" 30
}

test_qbittorrent_http() {
  assert_print_test_header "qbittorrent_http"
  assert_http_200 "http://localhost:8080" 30
}

test_jellyseerr_http() {
  assert_print_test_header "jellyseerr_http"
  assert_http_200 "http://localhost:5055" 30
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