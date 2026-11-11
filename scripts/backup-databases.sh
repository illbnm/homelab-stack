#!/usr/bin/env bash
# Usage: ./scripts/backup-databases.sh
# Dumps all PostgreSQL databases (pg_dumpall), triggers Redis BGSAVE, compresses to .tar.gz, retains 7 days, and optionally uploads to MinIO.
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/data/backups/databases}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
mkdir -p "$BACKUP_DIR"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

docker exec homelab-postgres pg_dumpall -U postgres > "${WORK_DIR}/postgres-all.sql"
docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD:-}" BGSAVE >/dev/null 2>&1 || true

ARCHIVE="${BACKUP_DIR}/databases-${STAMP}.tar.gz"
tar -czf "$ARCHIVE" -C "$WORK_DIR" .
find "$BACKUP_DIR" -name "databases-*.tar.gz" -mtime +"$RETENTION_DAYS" -delete

if [[ -n "${MINIO_ALIAS:-}" ]]; then
  mc cp "$ARCHIVE" "${MINIO_ALIAS}/homelab-backups/" || true
fi

echo "[OK] Database backup written to ${ARCHIVE}"
