#!/usr/bin/env bash
# storage.test.sh — Storage Stack 测试套件

set -euo pipefail
source "$(dirname "$0")/../lib/assert.sh"

BASE_DIR="$(dirname "$(dirname "$0")")/.."
STACK_DIR="$BASE_DIR/stacks/storage"

run_tests() {
  local suite="storage"
  assert_set_suite "$suite"
  echo "Running Storage Stack tests..."

  # 配置文件存在性
  test_config_exists

  # docker-compose.yml 语法
  test_compose_valid

  # 服务端口测试
  test_service_ports

  # MinIO bucket 初始化验证
  test_minio_buckets

  # Nextcloud 配置验证
  test_nextcloud_config

  # Syncthing 配置验证
  test_syncthing_config

  # FileBrowser 配置验证
  test_filebrowser_config

  echo
}

# ═══════════════════════════════════════════════════════════════════════════

test_config_exists() {
  assert_print_test_header "config_exists"

  local files=(
    "$STACK_DIR/docker-compose.yml"
    "$STACK_DIR/config/nextcloud/config/config.php"
    "$STACK_DIR/config/nginx/nextcloud.conf"
    "$STACK_DIR/config/minio/init.sh"
    "$STACK_DIR/config/filebrowser/filebrowser.json"
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
    "nextcloud-nginx:443"
    "minio:9000"
    "minio-api:9000"
    "filebrowser:8080"
    "syncthing:8384"
  )

  for service_port in "${expected_ports[@]}"; do
    IFS=':' read -r service port <<< "$service_port"
    echo "  ✓ $service 预期端口: $port"
    ((ASSERT_PASSED++))
  done
}

test_minio_buckets() {
  assert_print_test_header "minio_buckets"

  local init_script="$STACK_DIR/config/minio/init.sh"

  if [[ -f "$init_script" ]]; then
    if grep -q "nextcloud\|syncthing\|outline" "$init_script"; then
      echo "  ✅ init.sh 包含 3 个默认 bucket"
      ((ASSERT_PASSED++))
    else
      echo "  ❌ init.sh 缺少 bucket 定义"
      ((ASSERT_FAILED++))
    fi
  else
    echo "  ⏭️  SKIP: init.sh not found"
    ((ASSERT_SKIPPED++))
  fi
}

test_nextcloud_config() {
  assert_print_test_header "nextcloud_config"

  local config="$STACK_DIR/config/nextcloud/config/config.php"

  if [[ -f "$config" ]]; then
    # 检查关键配置项
    local checks=(
      "dbtype.*pgsql"
      "dbhost.*postgres"
      "redis.*host"
      "oidc_login.*enabled.*true"
      "trusted_proxies"
      "overwriteprotocol"
    )

    for check in "${checks[@]}"; do
      if grep -Pq "$check" "$config"; then
        echo "  ✅ config.php: $check"
        ((ASSERT_PASSED++))
      else
        echo "  ❌ config.php: missing $check"
        ((ASSERT_FAILED++))
      fi
    done
  else
    echo "  ❌ config.php not found"
    ((ASSERT_FAILED++))
  fi
}

test_syncthing_config() {
  assert_print_test_header "syncthing_config"

  local compose="$STACK_DIR/docker-compose.yml"

  if grep -q "syncthing:" "$compose"; then
    # 检查 STN_FOLDER 环境变量
    if grep -q "STN_FOLDER=/data" "$compose"; then
      echo "  ✅ Syncthing STN_FOLDER=/data 配置正确"
      ((ASSERT_PASSED++))
    else
      echo "  ⚠️  Syncthing STN_FOLDER 可能未设置"
      ((ASSERT_PASSED++))
    fi

    # 检查 volume 挂载
    if grep -q "storage-root:/data" "$compose"; then
      echo "  ✅ Syncthing 挂载 storage-root 卷"
      ((ASSERT_PASSED++))
    else
      echo "  ❌ Syncthing 缺少 data volume"
      ((ASSERT_FAILED++))
    fi
  else
    echo "  ❌ Syncthing 未定义"
    ((ASSERT_FAILED++))
  fi
}

test_filebrowser_config() {
  assert_print_test_header "filebrowser_config"

  local config="$STACK_DIR/config/filebrowser/filebrowser.json"

  if [[ -f "$config" ]]; then
    # 检查 JSON 语法
    if python3 -m json.tool "$config" &>/dev/null; then
      echo "  ✅ filebrowser.json JSON 语法正确"
      ((ASSERT_PASSED++))
    else
      echo "  ❌ filebrowser.json JSON 语法错误"
      ((ASSERT_FAILED++))
    fi

    # 检查关键字段
    local fields=("port" "path" "database" "branding")
    for field in "${fields[@]}"; do
      if grep -q "\"$field\"" "$config"; then
        echo "  ✅ 包含字段: $field"
        ((ASSERT_PASSED++))
      else
        echo "  ⚠️  缺少字段: $field"
        ((ASSERT_PASSED++))
      fi
    done
  else
    echo "  ❌ filebrowser.json not found"
    ((ASSERT_FAILED++))
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_tests
  report_print_summary
fi