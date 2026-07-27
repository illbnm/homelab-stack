#!/usr/bin/env bash
# scripts/backup-databases.sh - Automated PostgreSQL & Redis Backup with 7-day retention
# Usage: ./scripts/backup-databases.sh [backup-dir]

set -euo pipefail

BACKUP_DIR="${1:-/data/backups/databases}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-homelab-postgres}"
REDIS_CONTAINER="${REDIS_CONTAINER:-homelab-redis}"
POSTGRES_USER="${POSTGRES_ROOT_USER:-postgres}"

mkdir -p "$BACKUP_DIR"

echo "[DB Backup] Starting database dump at ${TIMESTAMP}..."

# 1. PostgreSQL pg_dumpall
PG_DUMP_FILE="${BACKUP_DIR}/pg_dumpall_${TIMESTAMP}.sql"
docker exec "$POSTGRES_CONTAINER" pg_dumpall -U "$POSTGRES_USER" > "$PG_DUMP_FILE"

# 2. Redis BGSAVE
echo "[DB Backup] Triggering Redis persistence..."
docker exec "$REDIS_CONTAINER" redis-cli BGSAVE || true

# 3. Compress Archive
ARCHIVE_FILE="${BACKUP_DIR}/homelab_db_backup_${TIMESTAMP}.tar.gz"
tar -czf "$ARCHIVE_FILE" -C "$BACKUP_DIR" "pg_dumpall_${TIMESTAMP}.sql"
rm -f "$PG_DUMP_FILE"

echo "[DB Backup] Archive created: ${ARCHIVE_FILE}"

# 4. Clean up backups older than 7 days
echo "[DB Backup] Cleaning archives older than 7 days..."
find "$BACKUP_DIR" -name "homelab_db_backup_*.tar.gz" -mtime +7 -delete

echo "[DB Backup] Completed successfully."
