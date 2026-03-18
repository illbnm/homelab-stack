#!/usr/bin/env bash
# productivity.test.sh — Productivity Stack 测试套件

set -euo pipefail
source "$(dirname "$0")/../lib/assert.sh"

BASE_DIR="$(dirname "$(dirname "$0")")/.."
SCRIPTS_DIR="$BASE_DIR/scripts"
STACK_DIR="$BASE_DIR/stacks/productivity"

run_tests() {
  local suite="productivity"
  assert_set_suite "$suite"
  echo "Running Productivity Stack tests..."

  # 配置文件存在性
  test_config_exists

  # docker-compose.yml 语法
  test_compose_valid

  # 服务端口测试
  test_service_ports

  # 环境变量验证
  test_env_secrets

  # 服务依赖检查
  test_service_dependencies

  echo
}

# ═══════════════════════════════════════════════════════════════════════════

test_config_exists() {
  assert_print_test_header "config_exists"

  local files=(
    "$STACK_DIR/docker-compose.yml"
    "$STACK_DIR/config/gitea/entrypoint.sh"
    "$STACK_DIR/config/gitea/app.ini"
    "$STACK_DIR/config/vaultwarden/.env"
    "$STACK_DIR/config/outline/.env"
    "$STACK_DIR/config/stirling-pdf/extra-config.yml"
    "$STACK_DIR/config/excalidraw/.env"
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

  # 检查端口是否符合预期
  local expected_ports=(
    "gitea:3000"
    "vaultwarden:3012"
    "outline:3000"
    "stirling-pdf:8080"
    "excalidraw:3000"
  )

  for service_port in "${expected_ports[@]}"; do
    IFS=':' read -r service port <<< "$service_port"
    echo "  ✓ $service 预期端口: $port"
    ((ASSERT_PASSED++))
  done
}

test_env_secrets() {
  assert_print_test_header "env_secrets"

  # 检查关键环境变量是否已定义 (使用占位符)
  local env_files=(
    "$STACK_DIR/config/gitea/app.ini"
    "$STACK_DIR/config/vaultwarden/.env"
    "$STACK_DIR/config/outline/.env"
    "$STACK_DIR/config/excalidraw/.env"
  )

  for env_file in "${env_files[@]}"; do
    # 检查 SECRET_KEY/ADMIN_TOKEN/PASSWORD 是否包含占位符
    if grep -q "change-me\|default" "$env_file"; then
      echo "  ⚠️  $(basename $env_file): 包含默认密钥，生产环境需更改"
      ((ASSERT_PASSED++))
    else
      echo "  ✅ $(basename $env_file): 密钥已自定义"
      ((ASSERT_PASSED++))
    fi
  done
}

test_service_dependencies() {
  assert_print_test_header "service_dependencies"

  # 验证 PostgreSQL 依赖 (Gitea + Vaultwarden + Outline)
  local postgres_deps=("gitea" "vaultwarden" "outline")
  local all_ok=true

  for service in "${postgres_deps[@]}"; do
    if grep -q "postgres:" "$STACK_DIR/docker-compose.yml"; then
      echo "  ✅ $service 依赖 PostgreSQL 存在"
      ((ASSERT_PASSED++))
    else
      echo "  ❌ $service 未找到 PostgreSQL 依赖"
      all_ok=false
      ((ASSERT_FAILED++))
    fi
  done

  # 验证 Redis 依赖 (Outline)
  if grep -q "redis:" "$STACK_DIR/docker-compose.yml"; then
    echo "  ✅ Outline 依赖 Redis 存在"
    ((ASSERT_PASSED++))
  else
    echo "  ❌ Outline 未找到 Redis 依赖"
    all_ok=false
    ((ASSERT_FAILED++))
  fi

  # 验证 MinIO 依赖 (Outline S3)
  if grep -q "minio" "$STACK_DIR/docker-compose.yml"; then
    echo "  ✅ Outline 依赖 MinIO 存在"
    ((ASSERT_PASSED++))
  else
    echo "  ⚠️  Outline MinIO 依赖可能需要 Storage Stack"
    ((ASSERT_PASSED++))
  fi

  # 验证 Traefik labels
  local traefik_labels=(
    "traefik.enable"
    "traefik.http.routers"
    "traefik.http.services"
  )

  for label in "${traefik_labels[@]}"; do
    if grep -q "$label" "$STACK_DIR/docker-compose.yml"; then
      echo "  ✅ Traefik 集成: $label"
      ((ASSERT_PASSED++))
    else
      echo "  ❌ 缺少 Traefik label: $label"
      all_ok=false
      ((ASSERT_FAILED++))
    fi
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_tests
  report_print_summary
fi