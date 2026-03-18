#!/usr/bin/env bash
# =============================================================================
# backup-databases.sh — 数据库备份脚本
# 备份 PostgreSQL + Redis，压缩为 .tar.gz，保留最近 7 天
#
# Usage:
#   ./scripts/backup-databases.sh [--upload-minio]
# =============================================================================

set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a; source "$ENV_FILE"; set +a
fi

BACKUP_DIR="${BACKUP_DIR:-/opt/homelab/backups/databases}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_NAME="db-backup-${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

mkdir -p "${BACKUP_PATH}"

# ── PostgreSQL ───────────────────────────────────────────────────────────────

echo "[backup] Starting PostgreSQL backup..."
docker exec postgres pg_dumpall -U postgres > "${BACKUP_PATH}/pg_dumpall.sql" 2>&1
if [[ $? -eq 0 ]]; then
  echo "[backup] ✅ PostgreSQL backup complete"
else
  echo "[backup] ❌ PostgreSQL backup failed"
fi

# ── Redis ────────────────────────────────────────────────────────────────────

echo "[backup] Starting Redis backup..."
docker exec redis redis-cli -a "${REDIS_PASSWORD:-changeme}" BGSAVE >/dev/null 2>&1
sleep 2  # Wait for BGSAVE to complete
docker cp redis:/data/dump.rdb "${BACKUP_PATH}/redis-dump.rdb" 2>&1
if [[ $? -eq 0 ]]; then
  echo "[backup] ✅ Redis backup complete"
else
  echo "[backup] ❌ Redis backup failed"
fi

# ── Compress ─────────────────────────────────────────────────────────────────

echo "[backup] Compressing..."
cd "${BACKUP_DIR}"
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}/"
rm -rf "${BACKUP_PATH}"
echo "[backup] ✅ Archive: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"

# ── Retention ────────────────────────────────────────────────────────────────

echo "[backup] Cleaning backups older than ${RETENTION_DAYS} days..."
find "${BACKUP_DIR}" -name "db-backup-*.tar.gz" -mtime "+${RETENTION_DAYS}" -delete
echo "[backup] ✅ Retention policy applied"

# ── Optional: Upload to MinIO ────────────────────────────────────────────────

if [[ "${1:-}" == "--upload-minio" ]] && command -v mc &>/dev/null; then
  echo "[backup] Uploading to MinIO..."
  mc cp "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" "minio/backups/databases/${BACKUP_NAME}.tar.gz"
  echo "[backup] ✅ Uploaded to MinIO"
fi

# ── Notify ───────────────────────────────────────────────────────────────────

ARCHIVE_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | cut -f1)
if [[ -x "${SCRIPT_DIR}/notify.sh" ]]; then
  "${SCRIPT_DIR}/notify.sh" homelab-backups "DB Backup Complete" "Archive: ${BACKUP_NAME}.tar.gz (${ARCHIVE_SIZE})" 3
fi

echo "[backup] ✅ Database backup complete: ${BACKUP_NAME}.tar.gz (${ARCHIVE_SIZE})"
