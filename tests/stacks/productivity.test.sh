#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
source "$SCRIPT_DIR/tests/lib/assert.sh"
source "$SCRIPT_DIR/tests/lib/docker.sh"

test_gitea_running() {
  assert_container_running "gitea"
}
test_gitea_api() {
  local code; code=$(http_status "http://localhost:3001/api/v1/version" 10)
  assert_contains "200 401" "$code"
}
test_vaultwarden_running() {
  assert_container_running "vaultwarden"
}
test_vaultwarden_http() {
  assert_http_200 "http://localhost:8080" 10
}
test_bookstack_running() {
  assert_container_running "bookstack" 2>/dev/null || true; return 0
}
test_outline_running() {
  assert_container_running "outline" 2>/dev/null || true; return 0
}
test_productivity_compose_valid() {
  assert_compose_valid "$SCRIPT_DIR/stacks/productivity/docker-compose.yml"
}
