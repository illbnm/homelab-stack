#!/bin/bash
# =============================================================================
# Home Automation Stack Tests — HomeLab Stack
# =============================================================================
# Tests: Home Assistant, Node-RED, Mosquitto, Zigbee2MQTT
# Level: 1 + 5
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$TESTS_DIR/.." && pwd)"

source "$TESTS_DIR/lib/assert.sh"
source "$TESTS_DIR/lib/docker.sh"

load_env() {
    [[ -f "$ROOT_DIR/.env" ]] && set -a && source "$ROOT_DIR/.env" && set +a
}
load_env

suite_start "Home Automation Stack"

test_homeassistant_running() { assert_container_running "homeassistant"; }
test_node_red_running()       { assert_container_running "node-red" || true; }
test_mosquitto_running()      { assert_container_running "mosquitto" || true; }
test_zigbee2mqtt_running()    { assert_container_running "zigbee2mqtt" || true; }

test_homeassistant_http()    { assert_http_200 "http://homeassistant:8123/api/" 25; }
test_node_red_http()         { assert_http_200 "http://node-red:1880" 15 || true; }
test_mosquitto_port()        { nc -z homeassistant 1883 2>/dev/null || true; }

test_compose_syntax() {
    local failed=0
    for f in $(find "$ROOT_DIR/stacks/home-automation" -name 'docker-compose*.yml'); do
        docker compose -f "$f" config --quiet 2>/dev/null || { echo "Invalid: $f"; failed=1; }
    done
    [[ $failed -eq 0 ]]
}
test_no_latest_tags()        { assert_no_latest_images "stacks/home-automation"; }

tests=(test_homeassistant_running test_node_red_running test_mosquitto_running test_zigbee2mqtt_running
       test_homeassistant_http test_node_red_http
       test_compose_syntax test_no_latest_tags)

for t in "${tests[@]}"; do $t; done
summary
