#!/bin/bash
# =============================================================================
# home-automation.test.sh - Home Automation stack tests
# =============================================================================

test_compose_syntax() {
    local start=$(date +%s)
    local result="PASS"
    
    docker compose -f stacks/home-automation/docker-compose.yml config --quiet 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "Compose syntax" "$result" $((end - start))
}

test_home_assistant_running() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_running "homeassistant" 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "Home Assistant running" "$result" $((end - start))
}

test_nodered_running() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_running "nodered" 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "Node-RED running" "$result" $((end - start))
}

test_mosquitto_running() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_running "mosquitto" 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "Mosquitto running" "$result" $((end - start))
}

test_zigbee2mqtt_running() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_running "zigbee2mqtt" 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "Zigbee2MQTT running" "$result" $((end - start))
}

test_esphome_running() {
    local start=$(date +%s)
    local result="PASS"
    
    assert_container_running "esphome" 2>&1 || result="FAIL"
    
    local end=$(date +%s)
    print_test_result "ESPHome running" "$result" $((end - start))
}

# Run all tests
test_compose_syntax
test_home_assistant_running
test_nodered_running
test_mosquitto_running
test_zigbee2mqtt_running
test_esphome_running
