#!/usr/bin/env bash
# =============================================================================
# Home Automation Stack Tests
# =============================================================================

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
  assert_http_200 "http://localhost:1880" 10
}

run_test_with_timing "home-automation" test_homeassistant_running "Home Assistant running"
run_test_with_timing "home-automation" test_homeassistant_http "Home Assistant HTTP 200"
run_test_with_timing "home-automation" test_node_red_running "Node-RED running"
run_test_with_timing "home-automation" test_node_red_http "Node-RED HTTP 200"
