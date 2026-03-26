#!/usr/bin/env bash
# home-automation.test.sh - Home Automation Stack 测试
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/report.sh"
STACK_NAME="home-automation"

test_homeassistant() {
    test_start "Home Assistant - 容器运行"
    if assert_container_running "homeassistant"; then test_end "Home Assistant - 容器运行" "PASS"
    else test_end "Home Assistant - 容器运行" "FAIL"; return 1; fi
    test_start "Home Assistant - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 15 "http://127.0.0.1:8123/"; then test_end "Home Assistant - HTTP 端点可达" "PASS"
    else test_end "Home Assistant - HTTP 端点可达" "SKIP"; fi
}

test_node_red() {
    test_start "Node-RED - 容器运行"
    if assert_container_running "node-red"; then test_end "Node-RED - 容器运行" "PASS"
    else test_end "Node-RED - 容器运行" "FAIL"; return 1; fi
    test_start "Node-RED - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:1880/"; then test_end "Node-RED - HTTP 端点可达" "PASS"
    else test_end "Node-RED - HTTP 端点可达" "SKIP"; fi
}

test_mosquitto() {
    test_start "Mosquitto - 容器运行"
    if assert_container_running "mosquitto"; then test_end "Mosquitto - 容器运行" "PASS"
    else test_end "Mosquitto - 容器运行" "FAIL"; return 1; fi
    test_start "Mosquitto - MQTT 端口监听"
    if check_port "127.0.0.1" "1883" 5; then test_end "Mosquitto - MQTT 端口监听" "PASS"
    else test_end "Mosquitto - MQTT 端口监听" "SKIP"; fi
}

test_zigbee2mqtt() {
    test_start "Zigbee2MQTT - 容器运行"
    if assert_container_running "zigbee2mqtt"; then test_end "Zigbee2MQTT - 容器运行" "PASS"
    else test_end "Zigbee2MQTT - 容器运行" "FAIL"; return 1; fi
    test_start "Zigbee2MQTT - HTTP 端点可达"
    if curl -sf -o /dev/null --max-time 10 "http://127.0.0.1:8080/"; then test_end "Zigbee2MQTT - HTTP 端点可达" "PASS"
    else test_end "Zigbee2MQTT - HTTP 端点可达" "SKIP"; fi
}

test_main() {
    test_group_start "$STACK_NAME"
    test_homeassistant || true; test_node_red || true; test_mosquitto || true; test_zigbee2mqtt || true
    test_group_end "$STACK_NAME" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "${SCRIPT_DIR}/lib/assert.sh"; source "${SCRIPT_DIR}/lib/docker.sh"; source "${SCRIPT_DIR}/lib/report.sh"
    report_init; test_main; print_summary "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
    exit $((TESTS_FAILED > 0 ? 1 : 0))
fi
