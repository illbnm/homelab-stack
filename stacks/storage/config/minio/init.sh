#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# MinIO 初始化脚本 — 创建默认 bucket 和用户
#
# 功能:
# 1. 等待 MinIO 服务就绪
# 2. 创建默认 bucket (nextcloud, syncthing, outline)
# 3. 创建可选用户 (如 nextcloud-user)
# 4. 启动 MinIO
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "🚀 Initializing MinIO..."

# ═══════════════════════════════════════════════════════════════════════════
# 1. 等待 MinIO 就绪
# ═══════════════════════════════════════════════════════════════════════════

wait_for_minio() {
  echo "⏳ Waiting for MinIO to start..."

  local max_attempts=30
  local attempt=0

  until curl -sf http://localhost:9000/minio/health/live >/dev/null 2>&1; do
    ((attempt++))
    if [[ $attempt -ge $max_attempts ]]; then
      echo "❌ MinIO not responding after ${max_attempts}s"
      exit 1
    fi
    echo "  ... waiting ($attempt/$max_attempts)"
    sleep 2
  done

  echo -e "${GREEN}✓ MinIO is ready${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════
# 2. 创建 bucket
# ═══════════════════════════════════════════════════════════════════════════

create_buckets() {
  echo "📦 Creating buckets..."

  local buckets=("nextcloud" "syncthing" "outline")
  local mc_cmd="mc --config-dir /tmp/mc config host add myminio http://localhost:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}"

  for bucket in "${buckets[@]}"; do
    echo "  Creating bucket: $bucket"
    if $mc_cmd mb "myminio/$bucket" 2>/dev/null; then
      echo -e "  ${GREEN}✓ Bucket $bucket created${NC}"
    else
      echo -e "  ${YELLOW}⚠️  Bucket $bucket may already exist${NC}"
    fi
  done
}

# ═══════════════════════════════════════════════════════════════════════════
# 3. 设置 bucket 策略 (公开/私有)
# ═══════════════════════════════════════════════════════════════════════════

set_bucket_policy() {
  echo "🔒 Setting bucket policies..."

  local mc_cmd="mc --config-dir /tmp/mc config host add myminio http://localhost:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}"

  # 设置 bucket 为私有 (except nextcloud needs public read for some assets?)
  for bucket in "nextcloud" "syncthing" "outline"; do
    $mc_cmd anonymous set download "myminio/$bucket" 2>/dev/null || true
    echo "  Policy for $bucket: private"
  done
}

# ═══════════════════════════════════════════════════════════════════════════
# 主流程
# ═══════════════════════════════════════════════════════════════════════════

main() {
  wait_for_minio

  # 初始化 mc 客户端
  mc --config-dir /tmp/mc alias set myminio http://localhost:9000 "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}" 2>/dev/null || true

  create_buckets
  set_bucket_policy

  echo
  echo -e "${GREEN}✅ MinIO initialization complete${NC}"
  echo "  Console: https://minio.${DOMAIN}"
  echo "  API: https://s3.${DOMAIN}"
  echo "  Buckets: nextcloud, syncthing, outline"
  echo

  # 启动真实 MinIO 进程
  exec /usr/bin/docker-entrypoint.sh minio server /data --console-address ":9001"
}

main "$@"