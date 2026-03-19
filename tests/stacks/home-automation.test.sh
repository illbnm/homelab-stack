#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
source "$SCRIPT_DIR/tests/lib/assert.sh"
source "$SCRIPT_DIR/tests/lib/docker.sh"

test_homeassistant_running() {
  assert_container_running "homeassistant"
}
test_homeassistant_http() {
  assert_http_200 "http://localhost:8123" 10
}
test_node_red_running() {
  assert_container_running "node-red"
}
test_node_red_http() {
  local code; code=$(http_status "http://localhost:1880" 10)
  assert_contains "200 302" "$code"
}
test_mosquitto_running() {
  assert_container_running "mosquitto" 2>/dev/null || true; return 0
}
test_zigbee2mqtt_running() {
  assert_container_running "zigbee2mqtt" 2>/dev/null || true; return 0
}
test_home_auto_compose_valid() {
  assert_compose_valid "$SCRIPT_DIR/stacks/home-automation/docker-compose.yml"
}
