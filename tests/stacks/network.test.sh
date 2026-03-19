#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
source "$SCRIPT_DIR/tests/lib/assert.sh"
source "$SCRIPT_DIR/tests/lib/docker.sh"

test_adguard_running() {
  assert_container_running "adguardhome"
}
test_adguard_http() {
  assert_http_200 "http://localhost:3053/control/status" 10
}
test_nginx_proxy_manager_running() {
  assert_container_running "nginx-proxy-manager"
}
test_nginx_proxy_manager_http() {
  local code; code=$(http_status "http://localhost:8181" 10)
  assert_contains "200 302" "$code"
}
test_network_compose_valid() {
  assert_compose_valid "$SCRIPT_DIR/stacks/network/docker-compose.yml"
}
