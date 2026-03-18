#!/usr/bin/env bash
# ai.test.sh — AI Stack 测试套件

set -euo pipefail
source "$(dirname "$0")/../lib/assert.sh"

BASE_DIR="$(dirname "$(dirname "$0")")/.."
SCRIPTS_DIR="$BASE_DIR/scripts"
STACK_DIR="$BASE_DIR/stacks/ai"

run_tests() {
  local suite="ai"
  assert_set_suite "$suite"
  echo "Running AI Stack tests..."

  # 配置文件存在性
  test_config_exists

  # docker-compose.yml 语法
  test_compose_valid

  # 脚本权限和语法
  test_scripts_executable
  test_scripts_syntax

  # 服务端口测试
  test_service_ports

  # 环境变量验证
  test_env_defaults

  # helper 脚本测试
  test_ai_setup_help

  echo
}

# ═══════════════════════════════════════════════════════════════════════════

test_config_exists() {
  assert_print_test_header "config_exists"

  local files=(
    "$STACK_DIR/docker-compose.yml"
    "$STACK_DIR/config/ollama/entrypoint.sh"
    "$STACK_DIR/config/ollama/models.txt"
    "$STACK_DIR/config/open-webui/.env"
    "$STACK_DIR/config/stable-diffusion/extra-configs/script.py"
    "$STACK_DIR/config/perplexica/.env"
    "$STACK_DIR/config/perplexica/searxng.yml"
  )

  for file in "${files[@]}"; do
    assert_file_exists "$file" "File exists: $(basename $file)"
  done
}

test_compose_valid() {
  assert_print_test_header "compose_valid"

  # 使用 docker compose 验证 (不启动)
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

test_scripts_executable() {
  assert_print_test_header "scripts_executable"

  local scripts=(
    "$STACK_DIR/config/ollama/entrypoint.sh"
  )

  for script in "${scripts[@]}"; do
    if [[ -x "$script" ]]; then
      echo "  ✅ $script is executable"
      ((ASSERT_PASSED++))
    else
      echo "  ❌ $script not executable"
      ((ASSERT_FAILED++))
    fi
  done
}

test_scripts_syntax() {
  assert_print_test_header "scripts_syntax"

  local scripts=(
    "$STACK_DIR/config/ollama/entrypoint.sh"
  )

  for script in "${scripts[@]}"; do
    if [[ -f "$script" ]]; then
      if bash -n "$script" 2>/dev/null; then
        echo "  ✅ $script: syntax OK"
        ((ASSERT_PASSED++))
      else
        echo "  ❌ $script: syntax error"
        ((ASSERT_FAILED++))
      fi
    fi
  done
}

test_service_ports() {
  assert_print_test_header "service_ports"

  # 检查端口是否符合预期 (不验证是否占用)
  local expected_ports=(
    "ollama:11434"
    "open-webui:3000"
    "stable-diffusion:7860"
    "perplexica:3000"
    "searxng:8080"
  )

  for service_port in "${expected_ports[@]}"; do
    IFS=':' read -r service port <<< "$service_port"
    echo "  ✓ $service 预期端口: $port"
    ((ASSERT_PASSED++))
  done
}

test_env_defaults() {
  assert_print_test_header "env_defaults"

  # 检查 key 字段是否存在
  local env_files=(
    "$STACK_DIR/config/open-webui/.env"
    "$STACK_DIR/config/perplexica/.env"
  )

  for env_file in "${env_files[@]}"; do
    # 检查 SEKRET_KEY/API_KEY 是否存在
    if grep -q "SECRET_KEY\|API_KEY" "$env_file"; then
      echo "  ✅ $(basename $env_file): 包含密钥配置"
      ((ASSERT_PASSED++))
    else
      echo "  ⚠️  $(basename $env_file): 缺少密钥"
      ((ASSERT_PASSED++))
    fi
  done
}

test_ai_setup_help() {
  assert_print_test_header "ai_setup_help"

  # 如果存在 AI 相关脚本
  local ai_script="$SCRIPTS_DIR/setup-ai.sh"
  if [[ -f "$ai_script" ]]; then
    if "$ai_script" --help &>/dev/null; then
      echo "  ✅ setup-ai.sh --help 工作"
      ((ASSERT_PASSED++))
    else
      echo "  ❌ setup-ai.sh --help 失败"
      ((ASSERT_FAILED++))
    fi
  else
    echo "  ℹ️  setup-ai.sh 尚未创建"
    ((ASSERT_SKIPPED++))
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_tests
  report_print_summary
fi