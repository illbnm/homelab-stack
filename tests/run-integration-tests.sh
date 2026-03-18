#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# run-integration-tests.sh — 集成测试完整流程
#
# 用法: ./tests/run-integration-tests.sh [OPTIONS]
#
# 功能:
# 1. 启动基础测试环境 (使用 CI 精简配置)
# 2. 运行所有测试套件
# 3. 生成报告
# 4. 清理环境
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/ci/docker-compose.test.yml"
RESULTS_DIR="$SCRIPT_DIR/results"

# 选项
CLEANUP=true
RUN_ALL=true
RUN_STACK=""
JSON_OUTPUT=false
VERBOSE=false

usage() {
  grep '^#' "$0" | cut -c4- | head -n 40
}

# ═══════════════════════════════════════════════════════════════════════════
# 主流程
# ═══════════════════════════════════════════════════════════════════════════

main() {
  echo
  echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║   HomeLab Integration Test Suite    ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
  echo

  # 1. 检查依赖
  check_deps

  # 2. 启动测试环境
  start_test_environment

  # 3. 等待服务就绪
  wait_for_services

  # 4. 运行测试
  run_tests

  # 5. 清理
  if $CLEANUP; then
    cleanup
  fi

  echo
  echo -e "${GREEN}✅ Integration test suite completed${NC}"
  echo
}

check_deps() {
  local missing=()

  for cmd in docker jq curl; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ Missing dependencies: ${missing[*]}"
    exit 1
  fi
}

start_test_environment() {
  echo -e "${BLUE}▶ Starting test environment...${NC}"
  docker compose -f "$COMPOSE_FILE" up -d

  echo -n "Waiting for all services..."
  local timeout=120
  local start=$(date +%s)
  while true; do
    local not_ready=$(docker ps --filter "status=restarting" --format '{{.Names}}' | wc -l | tr -d ' ')
    if [[ "$not_ready" -eq 0 ]]; then
      echo " ✅"
      break
    fi
    sleep 2
    local elapsed=$(($(date +%s) - start))
    if [[ $elapsed -ge $timeout ]]; then
      echo " ❌ (timeout)"
      echo "Some services failed to start, check logs:"
      docker compose -f "$COMPOSE_FILE" ps
      exit 1
    fi
  done
}

wait_for_services() {
  echo -e "${BLUE}▶ Waiting for services to be healthy...${NC}"

  # 等待关键服务
  wait_for_container_healthy "test-prometheus" 120
  wait_for_container_healthy "test-grafana" 180
  wait_for_container_healthy "test-loki" 120
  wait_for_container_healthy "test-alertmanager" 120
  wait_for_container_healthy "test-node-exporter" 60
  wait_for_container_healthy "test-cadvisor" 60

  # 等待 HTTP 端点
  wait_for_http "http://localhost:9090/-/healthy" 60
  wait_for_http "http://localhost:3000/api/health" 60
  wait_for_http "http://localhost:3100/ready" 60
  wait_for_http "http://localhost:9093/-/healthy" 60

  echo -e "${GREEN}✅ All services healthy${NC}"
}

run_tests() {
  echo -e "${BLUE}▶ Running test suites...${NC}"
  echo

  # 调用主测试脚本
  "$SCRIPT_DIR/run-tests.sh" --all --json
}

cleanup() {
  echo
  echo -e "${BLUE}▶ Cleaning up test environment...${NC}"
  docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true
  echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════

main "$@"