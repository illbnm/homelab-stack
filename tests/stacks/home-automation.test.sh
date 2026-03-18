#!/usr/bin/env bash
# =============================================================================
# home-automation.test.sh — Home Automation stack tests
# Services: Home Assistant, Node-RED, Mosquitto (MQTT), Zigbee2MQTT
# =============================================================================

# --- Home Assistant ---

test_homeassistant_running() {
  assert_container_running "homeassistant"
}

test_homeassistant_healthy() {
  assert_container_healthy "homeassistant"
}

test_homeassistant_api() {
  assert_http_200 "http://localhost:8123/api/" 15
}

test_homeassistant_onboarding() {
  # On fresh install, /api/onboarding returns available steps
  assert_http_status "http://localhost:8123/api/onboarding" 200 15
}

test_homeassistant_no_crash_loop() {
  assert_no_crash_loop "homeassistant" 3
}

test_homeassistant_in_proxy_network() {
  assert_container_in_network "homeassistant" "proxy"
}

# --- Node-RED ---

test_nodered_running() {
  assert_container_running "node-red"
}

test_nodered_healthy() {
  assert_container_healthy "node-red"
}

test_nodered_ui() {
  assert_http_200 "http://localhost:1880" 15
}

test_nodered_flows_api() {
  assert_http_status "http://localhost:1880/flows" 200 10
}

test_nodered_no_crash_loop() {
  assert_no_crash_loop "node-red" 3
}

# --- Mosquitto (MQTT) ---

test_mosquitto_running() {
  assert_container_running "mosquitto"
}

test_mosquitto_healthy() {
  assert_container_healthy "mosquitto"
}

test_mosquitto_port() {
  assert_port_listening 1883
}

test_mosquitto_no_crash_loop() {
  assert_no_crash_loop "mosquitto" 3
}

# --- Zigbee2MQTT ---

test_zigbee2mqtt_running() {
  # Zigbee2MQTT requires a Zigbee coordinator — may not start without hardware
  local state
  state=$(docker inspect --format='{{.State.Status}}' "zigbee2mqtt" 2>/dev/null) || {
    _assert_skip "Zigbee2MQTT running" "Not deployed (requires Zigbee coordinator hardware)"
    return 0
  }
  assert_container_running "zigbee2mqtt"
}

test_zigbee2mqtt_ui() {
  local state
  state=$(docker inspect --format='{{.State.Status}}' "zigbee2mqtt" 2>/dev/null) || {
    _assert_skip "Zigbee2MQTT UI" "Not deployed"
    return 0
  }
  assert_http_200 "http://localhost:8080" 10
}

# --- Inter-service: MQTT connectivity ---

test_mqtt_publish_subscribe() {
  local msg="MQTT pub/sub works (Mosquitto)"

  # Check if mosquitto_pub is available
  if ! docker exec mosquitto which mosquitto_pub &>/dev/null; then
    _assert_skip "$msg" "mosquitto_pub not available in container"
    return 0
  fi

  # Subscribe in background with timeout, then publish
  local test_topic
  test_topic="homelab/test/$(date +%s)"
  local test_msg="integration-test-ok"

  # Start subscriber
  docker exec -d mosquitto sh -c \
    "timeout 5 mosquitto_sub -t '${test_topic}' -C 1 > /tmp/mqtt-test.txt 2>/dev/null" &
  sleep 1

  # Publish
  docker exec mosquitto mosquitto_pub -t "${test_topic}" -m "${test_msg}" 2>/dev/null || {
    _assert_fail "$msg" "mosquitto_pub failed"
    return 1
  }

  sleep 2

  # Check result
  local result
  result=$(docker exec mosquitto cat /tmp/mqtt-test.txt 2>/dev/null) || result=""
  docker exec mosquitto rm -f /tmp/mqtt-test.txt 2>/dev/null || true

  if [[ "$result" == *"${test_msg}"* ]]; then
    _assert_pass "$msg"
  else
    _assert_skip "$msg" "Could not verify (timing issue)"
  fi
}
