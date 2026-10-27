#!/usr/bin/env bash
set -euo pipefail

test_homeassistant_running() { assert_container_healthy homeassistant; }
test_node_red_running() { assert_container_healthy node-red; }
test_mosquitto_running() { assert_container_healthy mosquitto; }
test_zigbee2mqtt_running() { assert_container_healthy zigbee2mqtt; }
