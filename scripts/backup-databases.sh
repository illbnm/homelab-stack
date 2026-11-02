#!/usr/bin/env bash
# HomeLab Database Backup Script
# PostgreSQL(pg_dumpall) + Redis(BGSAVE) + MariaDB(mysqldump) → 压缩 tar.gz，保留最近 7 天，可选上传 MinIO
# 用法: ./scripts/backup-databases.sh [--postgres|--redis|--mariadb|--all] [--upload]
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups/databases}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
UPLOAD=false

# 加载环境变量
ENV_FILE="$ROOT_DIR/stacks/databases/.env"
[ -f "$ENV_FILE" ] && { set -a; . "$ENV_FILE"; set +a; }

for arg in "$@"; do
  case "$arg" in
    --upload) UPLOAD=true ;;
  esac
done

mkdir -p "$BACKUP_DIR"

backup_postgres() {
  local dump="$BACKUP_DIR/postgres_${TIMESTAMP}.sql"
  docker exec homelab-postgres pg_dumpall -U "${POSTGRES_ROOT_USER:-postgres}" > "$dump"
  echo "[backup] postgres → $dump"
}

backup_redis() {
  docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" --no-auth-warning BGSAVE >/dev/null
  sleep 2
  local rdb="$BACKUP_DIR/redis_${TIMESTAMP}.rdb"
  docker cp homelab-redis:/data/dump.rdb "$rdb"
  echo "[backup] redis → $rdb"
}

backup_mariadb() {
  local dump="$BACKUP_DIR/mariadb_${TIMESTAMP}.sql"
  docker exec homelab-mariadb mariadb-dump --all-databases -u root -p"${MARIADB_ROOT_PASSWORD}" > "$dump" 2>/dev/null
  echo "[backup] mariadb → $dump"
}

upload_minio() {
  command -v mc >/dev/null 2>&1 || { echo "[backup] 未安装 mc 客户端，跳过 MinIO 上传"; return; }
  local bucket="${BACKUP_S3_BUCKET:-homelab-backups}"
  mc alias set minio-backup "$BACKUP_S3_ENDPOINT" "$BACKUP_S3_ACCESS_KEY" "$BACKUP_S3_SECRET_KEY" >/dev/null 2>&1
  mc mirror --overwrite "$BACKUP_DIR" "minio-backup/$bucket" >/dev/null
  echo "[backup] 已上传到 MinIO bucket $bucket"
}

cleanup_old() {
  find "$BACKUP_DIR" -type f \( -name '*.tar.gz' -o -name '*.sql' -o -name '*.rdb' \) -mtime +"$RETENTION_DAYS" -delete
  echo "[backup] 已清理超过 ${RETENTION_DAYS} 天的旧备份"
}

case "${1:---all}" in
  --postgres) backup_postgres ;;
  --redis)    backup_redis ;;
  --mariadb)  backup_mariadb ;;
  --all)
    backup_postgres
    backup_redis
    backup_mariadb
    ;;
  *) echo "Usage: $0 [--postgres|--redis|--mariadb|--all] [--upload]"; exit 1 ;;
esac

# 打包为 tar.gz 并清理原始文件
if ls "$BACKUP_DIR"/*_"${TIMESTAMP}".* >/dev/null 2>&1; then
  tar -czf "$BACKUP_DIR/databases_${TIMESTAMP}.tar.gz" -C "$BACKUP_DIR" \
    $(ls "$BACKUP_DIR" | grep "_${TIMESTAMP}\." | sed 's|^|./|')
  rm -f "$BACKUP_DIR"/postgres_"$TIMESTAMP".sql \
        "$BACKUP_DIR"/redis_"$TIMESTAMP".rdb \
        "$BACKUP_DIR"/mariadb_"$TIMESTAMP".sql
  echo "[backup] 归档 → databases_${TIMESTAMP}.tar.gz"
fi

$UPLOAD && upload_minio
cleanup_old
echo "[backup] 完成 (保留最近 ${RETENTION_DAYS} 天)"
