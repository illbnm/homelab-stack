#!/usr/bin/env bash

run_home_automation_tests() {
  CURRENT_SUITE="home-automation"
  assert_stack_static_checks home-automation
  assert_compose_services_declared home-automation homeassistant node-red mosquitto zigbee2mqtt
  assert_stack_containers_running homeassistant node-red mosquitto zigbee2mqtt
  assert_stack_containers_healthy homeassistant node-red mosquitto zigbee2mqtt
  assert_file_contains "$(stack_compose_file home-automation)" '1883:1883' "Mosquitto MQTT port is declared"
  assert_container_on_network homeassistant proxy "Home Assistant is attached to proxy network"
}
