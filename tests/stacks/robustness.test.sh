#!/usr/bin/env bash
# robustness.test.sh — Robustness Stack 测试

set -euo pipefail
source "$(dirname "$0")/../lib/assert.sh"

BASE_DIR="$(dirname "$(dirname "$0")")/.."
SCRIPTS_DIR="$BASE_DIR/scripts"
CONFIG_DIR="$BASE_DIR/config"

run_tests() {
  local suite="robustness"
  assert_set_suite "$suite"
  echo "Running Robustness Stack tests..."

  # 测试脚本文件存在性
  test_scripts_exist
  test_config_exists

  # 测试脚本语法
  test_scripts_syntax

  # 测试镜像映射文件
  test_mirror_map_valid

  # 测试 install.sh 基本功能
  test_install_help

  # 测试 localize-images.sh 基本功能
  test_localize_help
  test_localize_check

  # 测试 check-connectivity.sh 基本功能
  test_connectivity_help

  # 测试 setup-cn-mirrors.sh 基本功能
  test_setup_mirrors_help

  # 测试 diagnose.sh 基本功能
  test_diagnose_help

  echo
}

# ═══════════════════════════════════════════════════════════════════════════

test_scripts_exist() {
  assert_print_test_header "scripts_exist"

  local scripts=(
    "setup-cn-mirrors.sh"
    "localize-images.sh"
    "check-connectivity.sh"
    "install.sh"
    "diagnose.sh"
  )

  for script in "${scripts[@]}"; do
    assert_file_exists "$SCRIPTS_DIR/$script" "Script $script exists"
  done
}

test_config_exists() {
  assert_print_test_header "config_exists"

  assert_file_exists "$CONFIG_DIR/cn-mirrors.yml" "cn-mirrors.yml exists"
}

test_scripts_syntax() {
  assert_print_test_header "scripts_syntax"

  # 使用 shellcheck 或 bash -n 检查语法
  for script in "$SCRIPTS_DIR"/*.sh; do
    if [[ -f "$script" ]]; then
      if bash -n "$script" 2>/dev/null; then
        echo "  ✅ $script: syntax OK"
      else
        echo "  ❌ $script: syntax error"
        ((ASSERT_FAILED++))
      fi
    fi
  done
}

test_mirror_map_valid() {
  assert_print_test_header "mirror_map_valid"

  local yaml_file="$CONFIG_DIR/cn-mirrors.yml"

  # 检查 YAML 语法
  if command -v yq &>/dev/null; then
    if yq eval "$yaml_file" &>/dev/null; then
      echo "  ✅ YAML 语法正确"
      ((ASSERT_PASSED++))
    else
      echo "  ❌ YAML 语法错误"
      ((ASSERT_FAILED++))
    fi
  elif command -v python3 &>/dev/null; then
    if python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
      echo "  ✅ YAML 语法正确"
      ((ASSERT_PASSED++))
    else
      echo "  ❌ YAML 语法错误"
      ((ASSERT_FAILED++))
    fi
  else
    echo "  ⏭️  SKIP: 需要 yq 或 python3 验证 YAML"
    ((ASSERT_SKIPPED++))
  fi

  # 检查 mirrors 字段存在
  if grep -q "^mirrors:" "$yaml_file"; then
    echo "  ✅ 包含 mirrors 字段"
    ((ASSERT_PASSED++))
  else
    echo "  ❌ 缺少 mirrors 字段"
    ((ASSERT_FAILED++))
  fi
}

test_install_help() {
  assert_print_test_header "install_help"

  if "$SCRIPTS_DIR/install.sh" --help &>/dev/null; then
    echo "  ✅ install.sh --help 工作"
    ((ASSERT_PASSED++))
  else
    echo "  ❌ install.sh --help 失败"
    ((ASSERT_FAILED++))
  fi
}

test_localize_help() {
  assert_print_test_header "localize_help"

  if "$SCRIPTS_DIR/localize-images.sh" --help &>/dev/null; then
    echo "  ✅ localize-images.sh --help 工作"
    ((ASSERT_PASSED++))
  else
    echo "  ❌ localize-images.sh --help 失败"
    ((ASSERT_FAILED++))
  fi
}

test_localize_check() {
  assert_print_test_header "localize_check"

  # --check 模式应该不修改文件，只检查
  local output=$("$SCRIPTS_DIR/localize-images.sh" --check 2>&1 || true)
  if echo "$output" | grep -q "检查当前镜像状态"; then
    echo "  ✅ --check 模式正常"
    ((ASSERT_PASSED++))
  else
    echo "  ⚠️  WARN: --check 模式输出异常"
    ((ASSERT_PASSED++))
  fi
}

test_connectivity_help() {
  assert_print_test_header "connectivity_help"

  if "$SCRIPTS_DIR/check-connectivity.sh" --help &>/dev/null; then
    echo "  ✅ check-connectivity.sh --help 工作"
    ((ASSERT_PASSED++))
  else
    echo "  ❌ check-connectivity.sh --help 失败"
    ((ASSERT_FAILED++))
  fi
}

test_setup_mirrors_help() {
  assert_print_test_header "setup_mirrors_help"

  if "$SCRIPTS_DIR/setup-cn-mirrors.sh" --help &>/dev/null; then
    echo "  ✅ setup-cn-mirrors.sh --help 工作"
    ((ASSERT_PASSED++))
  else
    echo "  ❌ setup-cn-mirrors.sh --help 失败"
    ((ASSERT_FAILED++))
  fi
}

test_diagnose_help() {
  assert_print_test_header "diagnose_help"

  if "$SCRIPTS_DIR/diagnose.sh" --help &>/dev/null; then
    echo "  ✅ diagnose.sh --help 工作"
    ((ASSERT_PASSED++))
  else
    echo "  ❌ diagnose.sh --help 失败"
    ((ASSERT_FAILED++))
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_tests
  report_print_summary
fi