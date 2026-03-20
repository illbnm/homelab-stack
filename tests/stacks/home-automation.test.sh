#!/usr/bin/env bash
# =============================================================================
# Home Automation Stack Tests — Home Assistant, Node-RED, Mosquitto, Zigbee2MQTT
# =============================================================================

log_group "Home Automation"

# --- Level 1: Container health ---

HA_CONTAINERS=(homeassistant node-red mosquitto zigbee2mqtt)

for c in "${HA_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_running "$c"
    assert_container_healthy "$c"
    assert_container_not_restarting "$c"
  else
    skip_test "Container '$c'" "not running"
  fi
done

# --- Level 2: HTTP endpoints ---
if [[ "${TEST_LEVEL:-99}" -ge 2 ]]; then

  test_homeassistant_http() {
    require_container "homeassistant" || return
    assert_http_ok "http://localhost:8123" "Home Assistant Web UI"
  }

  test_nodered_http() {
    require_container "node-red" || return
    assert_http_ok "http://localhost:1880" "Node-RED Web UI"
  }

  test_mosquitto_port() {
    require_container "mosquitto" || return
    assert_port_open "localhost" 1883 "Mosquitto MQTT port 1883"
  }

  test_zigbee2mqtt_http() {
    require_container "zigbee2mqtt" || return
    assert_http_ok "http://localhost:8080" "Zigbee2MQTT Web UI"
  }

  test_homeassistant_http
  test_nodered_http
  test_mosquitto_port
  test_zigbee2mqtt_http
fi

# --- Level 3: Service interconnection ---
if [[ "${TEST_LEVEL:-99}" -ge 3 ]]; then

  # Zigbee2MQTT must connect to Mosquitto
  test_zigbee2mqtt_mosquitto() {
    require_container "zigbee2mqtt" || return
    require_container "mosquitto" || return
    # Test MQTT connectivity from inside zigbee2mqtt container
    local result
    result=$(docker_exec "mosquitto" \
      mosquitto_sub -t '$SYS/#' -C 1 -W 3 2>/dev/null || echo "timeout")
    if [[ "$result" != "timeout" && -n "$result" ]]; then
      _record_result pass "Mosquitto accepting MQTT subscriptions"
    else
      _record_result fail "Mosquitto accepting MQTT subscriptions" "timeout or empty"
    fi
  }

  test_zigbee2mqtt_mosquitto
fi

# --- Image tags ---
for c in "${HA_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_image_not_latest "$c"
  fi
done
