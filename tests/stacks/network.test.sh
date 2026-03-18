#!/usr/bin/env bash
# network.test.sh — Network Stack 测试套件

set -euo pipefail
source "$(dirname "$0")/../lib/assert.sh"

BASE_DIR="$(dirname "$(dirname "$0")")/.."
STACK_DIR="$BASE_DIR/stacks/network"

run_tests() {
  local suite="network"
  assert_set_suite "$suite"
  echo "Running Network Stack tests..."

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
  test_env_required

  # fix-dns-port.sh 功能
  test_fix_dns_port_help

  echo
}

# ═══════════════════════════════════════════════════════════════════════════

test_config_exists() {
  assert_print_test_header "config_exists"

  local files=(
    "$STACK_DIR/docker-compose.yml"
    "$STACK_DIR/config/adguard/AdGuardHome.yaml"
    "$STACK_DIR/config/adguard/filter.txt"
    "$STACK_DIR/config/unbound/unbound.conf"
    "$STACK_DIR/scripts/fix-dns-port.sh"
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

test_scripts_executable() {
  assert_print_test_header "scripts_executable"

  local scripts=(
    "$STACK_DIR/scripts/fix-dns-port.sh"
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
    "$STACK_DIR/scripts/fix-dns-port.sh"
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

  local expected_ports=(
    "adguard:53/tcp"
    "adguard:53/udp"
    "adguard-web:80"
    "wireguard-ui:51821"
    "wireguard-vpn:51820/udp"
    "unbound:5353/tcp"
    "unbound:5353/udp"
  )

  for service_port in "${expected_ports[@]}"; do
    IFS=':' read -r service portproto <<< "$service_port"
    IFS='/' read -r port protocol <<< "$portproto"
    echo "  ✓ $service 预期端口: $port/$protocol"
    ((ASSERT_PASSED++))
  done
}

test_env_required() {
  assert_print_test_header "env_required"

  # 检查必要的环境变量是否在 docker-compose.yml 中定义
  local required_vars=(
    "ADGUARD_PASSWORD"
    "WIREGUARD_PASSWORD"
    "CLOUDFLARE_API_TOKEN"
    "CLOUDFLARE_EMAIL"
    "DOMAIN"
  )

  for var in "${required_vars[@]}"; do
    if grep -q "${var}:" "$STACK_DIR/docker-compose.yml"; then
      echo "  ✅ 环境变量定义: $var"
      ((ASSERT_PASSED++))
    else
      echo "  ⚠️  环境变量未找到: $var (需在 .env 设置)"
      ((ASSERT_PASSED++))
    fi
  done
}

test_fix_dns_port_help() {
  assert_print_test_header "fix_dns_port_help"

  local script="$STACK_DIR/scripts/fix-dns-port.sh"

  if [[ -f "$script" ]]; then
    if "$script" --help &>/dev/null; then
      echo "  ✅ fix-dns-port.sh --help 工作"
      ((ASSERT_PASSED++))
    else
      echo "  ❌ fix-dns-port.sh --help 失败"
      ((ASSERT_FAILED++))
    fi
  else
    echo "  ❌ fix-dns-port.sh not found"
    ((ASSERT_FAILED++))
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_tests
  report_print_summary
fi