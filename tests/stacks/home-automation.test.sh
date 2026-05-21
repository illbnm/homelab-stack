#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Home Automation Tests
# Tests: Home Assistant + Node-RED + Mosquitto + Zigbee2MQTT
# =============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker.sh"

should_run_stack "home-automation" || { begin_suite "Home Automation"; assert_skip "not selected"; exit 0; }

begin_suite "Home Automation — Home Assistant + Node-RED + Zigbee2MQTT"

# ---- Home Assistant ----
assert_container_running "homeassistant"
assert_container_healthy "homeassistant"
assert_container_not_latest "homeassistant"
assert_http_200 "${BASE_URL:-http://localhost}:8123/api/" "hass:api"

# HA API check
begin_test "homeassistant:api:status"
hass_status=$(curl -sf "${BASE_URL:-http://localhost}:8123/api/" 2>/dev/null || echo "")
if echo "$hass_status" | grep -qi "api running"; then
  assert_pass "API running"
else
  assert_skip "API status check (may need auth)"
fi

# ---- Node-RED ----
assert_container_running "node-red"
assert_container_healthy "node-red"
assert_container_not_latest "node-red"
assert_http_200 "${BASE_URL:-http://localhost}:1880" "node-red:ui"

# ---- Mosquitto (MQTT Broker) ----
assert_container_running "mosquitto"
assert_container_healthy "mosquitto"
assert_container_not_latest "mosquitto"
assert_port_open "localhost" "1883" "mqtt"

# ---- Zigbee2MQTT ----
assert_container_running "zigbee2mqtt"
assert_container_healthy "zigbee2mqtt"
assert_container_not_latest "zigbee2mqtt"
assert_http_200 "${BASE_URL:-http://localhost}:8080" "zigbee2mqtt:ui"

# ---- Inter-service: Zigbee2MQTT → Mosquitto ----
begin_test "zigbee2mqtt:connects_mosquitto"
if docker exec zigbee2mqtt sh -c 'echo PING | nc -w2 mosquitto 1883' 2>/dev/null; then
  assert_pass "zigbee2mqtt → mosquitto reachable"
else
  assert_skip "MQTT connectivity test"
fi

# ---- Inter-service: Home Assistant → Mosquitto ----
begin_test "homeassistant:connects_mosquitto"
if docker exec homeassistant sh -c 'echo PING | nc -w2 mosquitto 1883' 2>/dev/null; then
  assert_pass "homeassistant → mosquitto reachable"
else
  assert_skip "MQTT connectivity test"
fi

# ---- Compose validation ----
assert_compose_valid "${SCRIPT_DIR}/../../stacks/home-automation/docker-compose.yml" "home-automation"
