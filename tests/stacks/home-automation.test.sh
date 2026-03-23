#!/usr/bin/env bash
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib"; pwd)"
source "$_LIB_DIR/assert.sh"

test_ha_homeassistant_running() { assert_container_running "homeassistant" "Home Assistant should be running"; }
test_ha_homeassistant_http() { assert_http_200 "http://localhost:8123" 15 "Home Assistant should respond"; }
test_ha_nodered_running() { assert_container_running "node-red" "Node-RED should be running"; }
test_ha_nodered_http() { assert_http_200 "http://localhost:1880" 15 "Node-RED should respond"; }
test_ha_no_latest_tags() { assert_no_latest_images "$BASE_DIR/stacks/home-automation" "Home automation should pin image versions"; }
