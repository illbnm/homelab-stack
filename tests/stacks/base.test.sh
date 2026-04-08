#!/usr/bin/env bash
# HomeLab Stack — Base Stack Tests

set -euo pipefail

# 测试 Traefik 运行状态
test_traefik_running() {
  assert_container_running "traefik"
}

# 测试 Traefik 健康状态
test_traefik_healthy() {
  assert_container_healthy "traefik" 60
}

# 测试 Portainer 运行状态
test_portainer_running() {
  assert_container_running "portainer"
}

# 测试 Portainer 健康状态
test_portainer_healthy() {
  assert_container_healthy "portainer" 60
}

# 测试 Watchtower 运行状态
test_watchtower_running() {
  assert_container_running "watchtower"
}

# 运行所有测试
run_all_tests() {
  echo "Testing Base Stack..."
  test_traefik_running
  test_traefik_healthy
  test_portainer_running
  test_portainer_healthy
  test_watchtower_running
  echo "Base Stack Tests Complete"
}

run_all_tests
