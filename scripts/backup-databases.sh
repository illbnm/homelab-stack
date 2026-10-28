#!/usr/bin/env bash
# scripts/backup-databases.sh
# Automated backup for shared PostgreSQL & Redis layers with 7-day retention

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/backups/databases}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
mkdir -p "${BACKUP_DIR}"

echo "[backup] Starting full database backup at ${TIMESTAMP}..."

# 1. PostgreSQL dumpall
PG_DUMP_FILE="${BACKUP_DIR}/postgres_all_${TIMESTAMP}.sql"
pg_dumpall -U "${POSTGRES_USER:-postgres}" -h "${POSTGRES_HOST:-postgres}" > "${PG_DUMP_FILE}"
gzip -f "${PG_DUMP_FILE}"
echo "[backup] PostgreSQL backup completed: ${PG_DUMP_FILE}.gz"

# 2. Redis BGSAVE trigger
echo "[backup] Triggering Redis background save..."
redis-cli -h "${REDIS_HOST:-redis}" BGSAVE || true

# 3. Retention policy: Remove backups older than 7 days
find "${BACKUP_DIR}" -type f -name "*.gz" -mtime +7 -delete
echo "[backup] Cleaned up archives older than 7 days."
