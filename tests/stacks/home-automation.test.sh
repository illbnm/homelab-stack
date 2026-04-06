#!/bin/bash
# home-automation.test.sh - Home Automation Stack Integration Tests
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$SCRIPT_DIR/../lib/assert.sh"

# ============================================================================
# Test: Docker Compose Configuration
# ============================================================================

test_compose_file_exists() {
    echo "[home-automation] Testing docker-compose.yml exists..."
    assert_file_exists "$ROOT_DIR/stacks/home-automation/docker-compose.yml"
}

test_compose_valid() {
    echo "[home-automation] Testing docker-compose.yml is valid..."
    assert_compose_valid "$ROOT_DIR/stacks/home-automation/docker-compose.yml"
}

test_mosquitto_config_exists() {
    echo "[home-automation] Testing mosquitto.conf exists..."
    assert_file_exists "$ROOT_DIR/stacks/home-automation/mosquitto.conf"
}

# ============================================================================
# Test: Service Configuration
# ============================================================================

test_homeassistant_config() {
    echo "[home-automation] Testing Home Assistant configuration..."
    local compose_file="$ROOT_DIR/stacks/home-automation/docker-compose.yml"
    
    # Check for host network mode (required for mDNS/UPnP)
    assert_file_contains "$compose_file" "network_mode: host" || true
    
    # Check image version
    assert_file_contains "$compose_file" "home-assistant:2024.9.3" || true
    
    # Check privileged mode
    assert_file_contains "$compose_file" "privileged: true" || true
}

test_nodered_config() {
    echo "[home-automation] Testing Node-RED configuration..."
    local compose_file="$ROOT_DIR/stacks/home-automation/docker-compose.yml"
    
    # Check image version
    assert_file_contains "$compose_file" "nodered/node-red:4.0.3" || true
}

test_mosquitto_config() {
    echo "[home-automation] Testing Mosquitto configuration..."
    local compose_file="$ROOT_DIR/stacks/home-automation/docker-compose.yml"
    local config_file="$ROOT_DIR/stacks/home-automation/mosquitto.conf"
    
    # Check image version
    assert_file_contains "$compose_file" "eclipse-mosquitto:2.0.19" || true
    
    # Check mosquitto.conf has basic config
    assert_file_contains "$config_file" "listener 1883" || true
    assert_file_contains "$config_file" "persistence true" || true
}

test_zigbee2mqtt_config() {
    echo "[home-automation] Testing Zigbee2MQTT configuration..."
    local compose_file="$ROOT_DIR/stacks/home-automation/docker-compose.yml"
    
    # Check image version
    assert_file_contains "$compose_file" "zigbee2mqtt:1.40.2" || true
    
    # Check depends_on mosquitto
    assert_file_contains "$compose_file" "depends_on:" || true
    assert_file_contains "$compose_file" "mosquitto:" || true
}

test_esphome_config() {
    echo "[home-automation] Testing ESPHome configuration..."
    local compose_file="$ROOT_DIR/stacks/home-automation/docker-compose.yml"
    
    # Check ESPHome service exists
    assert_file_contains "$compose_file" "esphome:" || true
    
    # Check image version
    assert_file_contains "$compose_file" "esphome:2024.9.3" || true
}

# ============================================================================
# Test: Container Status (if running)
# ============================================================================

test_homeassistant_running() {
    echo "[home-automation] Testing Home Assistant running..."
    assert_container_running "homeassistant" || true
}

test_nodered_running() {
    echo "[home-automation] Testing Node-RED running..."
    assert_container_running "node-red" || true
}

test_mosquitto_running() {
    echo "[home-automation] Testing Mosquitto running..."
    assert_container_running "mosquitto" || true
}

test_zigbee2mqtt_running() {
    echo "[home-automation] Testing Zigbee2MQTT running..."
    assert_container_running "zigbee2mqtt" || true
}

test_esphome_running() {
    echo "[home-automation] Testing ESPHome running..."
    assert_container_running "esphome" || true
}

# ============================================================================
# Test: Health Checks (if running)
# ============================================================================

test_homeassistant_healthy() {
    echo "[home-automation] Testing Home Assistant healthy..."
    assert_container_healthy "homeassistant" 120 || true
}

test_nodered_healthy() {
    echo "[home-automation] Testing Node-RED healthy..."
    assert_container_healthy "node-red" 60 || true
}

test_mosquitto_healthy() {
    echo "[home-automation] Testing Mosquitto healthy..."
    assert_container_healthy "mosquitto" 60 || true
}

test_zigbee2mqtt_healthy() {
    echo "[home-automation] Testing Zigbee2MQTT healthy..."
    assert_container_healthy "zigbee2mqtt" 60 || true
}

test_esphome_healthy() {
    echo "[home-automation] Testing ESPHome healthy..."
    assert_container_healthy "esphome" 60 || true
}

# ============================================================================
# Test: HTTP Endpoints (if running)
# ============================================================================

test_homeassistant_http() {
    echo "[home-automation] Testing Home Assistant HTTP..."
    assert_http_200 "http://localhost:8123" 30 || true
}

test_nodered_http() {
    echo "[home-automation] Testing Node-RED HTTP..."
    assert_http_200 "http://localhost:1880" 30 || true
}

test_zigbee2mqtt_http() {
    echo "[home-automation] Testing Zigbee2MQTT HTTP..."
    assert_http_200 "http://localhost:8080" 30 || true
}

test_esphome_http() {
    echo "[home-automation] Testing ESPHome HTTP..."
    assert_http_200 "http://localhost:6052" 30 || true
}

# ============================================================================
# Test: No Latest Tags
# ============================================================================

test_no_latest_tags() {
    echo "[home-automation] Testing no :latest image tags..."
    assert_no_latest_tags "$ROOT_DIR/stacks/home-automation" || true
}

# ============================================================================
# Run All Tests
# ============================================================================

run_home_automation_tests() {
    echo "╔══════════════════════════════════════╗"
    echo "║   HomeLab Stack — Home Automation    ║"
    echo "║           Integration Tests          ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    
    echo "━━━ Configuration Tests ━━━"
    test_compose_file_exists
    test_compose_valid
    test_mosquitto_config_exists
    test_homeassistant_config
    test_nodered_config
    test_mosquitto_config
    test_zigbee2mqtt_config
    test_esphome_config
    test_no_latest_tags
    
    echo ""
    echo "━━━ Container Status Tests ━━━"
    test_homeassistant_running || true
    test_nodered_running || true
    test_mosquitto_running || true
    test_zigbee2mqtt_running || true
    test_esphome_running || true
    
    echo ""
    echo "━━━ Health Check Tests ━━━"
    test_homeassistant_healthy || true
    test_nodered_healthy || true
    test_mosquitto_healthy || true
    test_zigbee2mqtt_healthy || true
    test_esphome_healthy || true
    
    echo ""
    echo "━━━ HTTP Endpoint Tests ━━━"
    test_homeassistant_http || true
    test_nodered_http || true
    test_zigbee2mqtt_http || true
    test_esphome_http || true
    
    print_summary $ASSERTIONS_PASSED $ASSERTIONS_FAILED $ASSERTIONS_SKIPPED
    
    # Generate JSON report
    generate_json_report "$ROOT_DIR/tests/results" "home-automation"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_home_automation_tests
fi