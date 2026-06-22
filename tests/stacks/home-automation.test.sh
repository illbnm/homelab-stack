test_homeassistant_running() {
  assert_container_running "homeassistant"
  assert_container_healthy "homeassistant"
}

test_node_red_running() {
  assert_container_running "node-red"
  assert_container_healthy "node-red"
}

test_mosquitto_running() {
  assert_container_running "mosquitto"
  assert_container_healthy "mosquitto"
}

test_zigbee2mqtt_running() {
  assert_container_running "zigbee2mqtt"
  assert_container_healthy "zigbee2mqtt"
}

