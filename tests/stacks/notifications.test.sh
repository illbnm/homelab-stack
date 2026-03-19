#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
source "$SCRIPT_DIR/tests/lib/assert.sh"
source "$SCRIPT_DIR/tests/lib/docker.sh"

test_ntfy_running() {
  assert_container_running "ntfy"
}
test_ntfy_http() {
  assert_http_200 "http://localhost:2586" 10
}
test_notifications_compose_valid() {
  assert_compose_valid "$SCRIPT_DIR/stacks/notifications/docker-compose.yml"
}
