#!/usr/bin/env bash
# Home automation stack tests
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

test_homeassistant_running() {
  assert_container_running "homeassistant"
  assert_http_200 "http://localhost:8123"
}

test_nodered_running() {
  assert_container_running "node-red"
  assert_container_healthy "node-red"
  assert_http_200 "http://localhost:1880"
}

test_mosquitto_running() {
  assert_container_running "mosquitto"
  assert_container_healthy "mosquitto"
  assert_port_open "localhost" "1883"
}

test_zigbee2mqtt_running() {
  assert_container_running "zigbee2mqtt"
  assert_http_200 "http://localhost:8080"
}

test_esphome_running() {
  assert_container_running "esphome"
  assert_http_200 "http://localhost:6052"
}

run_test test_homeassistant_running
run_test test_nodered_running
run_test test_mosquitto_running
run_test test_zigbee2mqtt_running
run_test test_esphome_running
