#!/usr/bin/env bash
# home-automation.test.sh — Home Automation Stack 测试套件

set -euo pipefail
source "$(dirname "$0")/../lib/assert.sh"

BASE_DIR="$(dirname "$(dirname "$0")")/.."
STACK_DIR="$BASE_DIR/stacks/home-automation"

run_tests() {
  local suite="home-automation"
  assert_set_suite "$suite"
  echo "Running Home Automation Stack tests..."

  # 配置文件存在性
  test_config_exists

  # docker-compose.yml 语法
  test_compose_valid

  # 服务端口测试
  test_service_ports

  # Home Assistant 特殊配置验证
  test_homeassistant_config

  # Mosquitto 配置验证
  test_mosquitto_config

  # Zigbee2MQTT 配置验证
  test_zigbee2mqtt_config

  # ESPHome 配置验证
  test_esphome_config

  # network_mode 验证
  test_network_mode

  echo
}

# ═══════════════════════════════════════════════════════════════════════════

test_config_exists() {
  assert_print_test_header "config_exists"

  local files=(
    "$STACK_DIR/docker-compose.yml"
    "$STACK_DIR/config/homeassistant/configuration.yaml"
    "$STACK_DIR/config/homeassistant/automations.yaml"
    "$STACK_DIR/config/mosquitto/mosquitto.conf"
    "$STACK_DIR/config/mosquitto/passwords"
    "$STACK_DIR/config/mosquitto/acl"
    "$STACK_DIR/config/zigbee2mqtt/configuration.yaml"
    "$STACK_DIR/config/zigbee2mqtt/devices-init.yaml"
    "$STACK_DIR/config/esphome/esphome.yaml"
  )

  for file in "${files[@]}"; do
    assert_file_exists "$file" "File exists: $(basename $file)"
  done
}

test_compose_valid() {
  assert_print_test_header "compose_valid"

  if command -v docker &>/dev/null; then
    if docker compose -f "$STACK_DIR/docker-compose.yml" config &>/dev/null; then
      echo "  ✅ docker-compose.yml syntax valid"
      ((ASSERT_PASSED++))
    else
      echo "  ❌ docker-compose.yml syntax error"
      ((ASSERT_FAILED++))
    fi
  else
    echo "  ⏭️  SKIP: Docker not installed"
    ((ASSERT_SKIPPED++))
  fi
}

test_service_ports() {
  assert_print_test_header "service_ports"

  local expected_ports=(
    "homeassistant:8123"
    "nodered:1880"
    "mosquitto:1883"
    "mosquitto:8883"
    "mosquitto:9001"
    "zigbee2mqtt:8080"
    "esphome:6052"
  )

  for service_port in "${expected_ports[@]}"; do
    IFS=':' read -r service port <<< "$service_port"
    echo "  ✓ $service 预期端口: $port"
    ((ASSERT_PASSED++))
  done
}

test_homeassistant_config() {
  assert_print_test_header "homeassistant_config"

  local config="$STACK_DIR/config/homeassistant/configuration.yaml"

  if [[ -f "$config" ]]; then
    # 检查关键配置项
    local checks=(
      "external_url.*ha\.\${DOMAIN}"
      "mqtt:"
      "recorder:"
      "frontend:"
      "api:"
    )

    for check in "${checks[@]}"; do
      if grep -Pq "$check" "$config"; then
        echo "  ✅ configuration.yaml: $check"
        ((ASSERT_PASSED++))
      else
        echo "  ⚠️  configuration.yaml: missing $check"
        ((ASSERT_PASSED++))
      fi
    done

    # 检查 MQTT 配置是否指向 mosquitto
    if grep -q "broker: mosquitto" "$config"; then
      echo "  ✅ MQTT broker 指向 mosquitto"
      ((ASSERT_PASSED++))
    else
      echo "  ❌ MQTT broker 未指向 mosquitto"
      ((ASSERT_FAILED++))
    fi
  else
    echo "  ❌ configuration.yaml not found"
    ((ASSERT_FAILED++))
  fi
}

test_mosquitto_config() {
  assert_print_test_header "mosquitto_config"

  local config="$STACK_DIR/config/mosquitto/mosquitto.conf"

  if [[ -f "$config" ]]; then
    # 检查关键配置
    local checks=(
      "listener 1883"
      "listener 8883"
      "listener 9001"
      "allow_anonymous false"
      "password_file"
      "acl_file"
    )

    for check in "${checks[@]}"; do
      if grep -q "$check" "$config"; then
        echo "  ✅ mosquitto.conf: $check"
        ((ASSERT_PASSED++))
      else
        echo "  ⚠️  mosquitto.conf: missing $check"
        ((ASSERT_PASSED++))
      fi
    done
  else
    echo "  ❌ mosquitto.conf not found"
    ((ASSERT_FAILED++))
  fi

  # 检查密码文件
  if [[ -f "$STACK_DIR/config/mosquitto/passwords" ]]; then
    echo "  ✅ passwords file exists"
    ((ASSERT_PASSED++))
  else
    echo "  ⚠️  passwords file missing (需生成真实密码)"
    ((ASSERT_PASSED++))
  fi
}

test_zigbee2mqtt_config() {
  assert_print_test_header "zigbee2mqtt_config"

  local config="$STACK_DIR/config/zigbee2mqtt/configuration.yaml"

  if [[ -f "$config" ]]; then
    # 检查关键配置
    local checks=(
      "homeassistant: true"
      "discovery:"
      "mqtt:"
      "serial:"
      "port: /dev/ttyUSB0"
    )

    for check in "${checks[@]}"; do
      if grep -Pq "$check" "$config"; then
        echo "  ✅ configuration.yaml: $check"
        ((ASSERT_PASSED++))
      else
        echo "  ⚠️  configuration.yaml: missing $check"
        ((ASSERT_PASSED++))
      fi
    done
  else
    echo "  ❌ configuration.yaml not found"
    ((ASSERT_FAILED++))
  fi
}

test_esphome_config() {
  assert_print_test_header "esphome_config"

  local config="$STACK_DIR/config/esphome/esphome.yaml"

  if [[ -f "$config" ]]; then
    # 检查关键配置
    local checks=(
      "esphome:"
      "api:"
      "web_server:"
      "logger:"
    )

    for check in "${checks[@]}"; do
      if grep -Pq "$check" "$config"; then
        echo "  ✅ esphome.yaml: $check"
        ((ASSERT_PASSED++))
      else
        echo "  ⚠️  esphome.yaml: missing $check"
        ((ASSERT_PASSED++))
      fi
    done
  else
    echo "  ❌ esphome.yaml not found"
    ((ASSERT_FAILED++))
  fi
}

test_network_mode() {
  assert_print_test_header "network_mode"

  local compose="$STACK_DIR/docker-compose.yml"

  # 检查 Home Assistant 是否使用 network_mode: host
  if grep -A5 "homeassistant:" "$compose" | grep -q "network_mode: host"; then
    echo "  ✅ Home Assistant 使用 network_mode: host"
    ((ASSERT_PASSED++))
  else
    echo "  ❌ Home Assistant 未设置 network_mode: host"
    ((ASSERT_FAILED++))
  fi

  # 检查其他服务不使用 host 模式
  local other_services=("nodered" "mosquitto" "zigbee2mqtt" "esphome")
  for service in "${other_services[@]}"; do
    if grep -A5 "$service:" "$compose" | grep -q "network_mode: host"; then
      echo "  ⚠️  $service 不建议使用 host 网络模式"
      ((ASSERT_PASSED++))
    else
      echo "  ✅ $service 使用正常网络模式"
      ((ASSERT_PASSED++))
    fi
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_tests
  report_print_summary
fi