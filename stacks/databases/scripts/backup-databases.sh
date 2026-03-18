#!/bin/bash
# =============================================================================
# HomeLab Database Backup Script
#
# Backs up PostgreSQL (pg_dumpall), Redis (BGSAVE), and MariaDB (mariadb-dump).
# Compresses everything into a timestamped .tar.gz archive.
# Retains backups for the last 7 days (configurable via BACKUP_RETENTION_DAYS).
#
# Usage:
#   ./backup-databases.sh                    # Run from host (uses docker exec)
#   BACKUP_DIR=/custom/path ./backup-databases.sh   # Custom backup location
#
# Prerequisites:
#   - Docker containers must be running: homelab-postgres, homelab-redis, homelab-mariadb
#   - POSTGRES_ROOT_USER, POSTGRES_ROOT_PASSWORD, REDIS_PASSWORD,
#     MARIADB_ROOT_PASSWORD must be set (or sourced from .env)
# =============================================================================
set -euo pipefail

# ---- Configuration ----
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab/backups/databases}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
WORK_DIR="${BACKUP_DIR}/tmp-${TIMESTAMP}"
SUCCESSES=0
FAILURES=0

# Load .env if present (for container passwords)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

# Validate required vars
: "${POSTGRES_ROOT_USER:?POSTGRES_ROOT_USER is required}"
: "${POSTGRES_ROOT_PASSWORD:?POSTGRES_ROOT_PASSWORD is required}"
: "${REDIS_PASSWORD:?REDIS_PASSWORD is required}"
: "${MARIADB_ROOT_PASSWORD:?MARIADB_ROOT_PASSWORD is required}"

mkdir -p "$WORK_DIR"

echo "[backup] Starting database backup at ${TIMESTAMP}"
echo "[backup] Backup directory: ${BACKUP_DIR}"

# ---- PostgreSQL: pg_dumpall ----
echo "[backup] Dumping PostgreSQL (all databases)..."
if docker exec homelab-postgres pg_dumpall \
    -U "${POSTGRES_ROOT_USER}" \
    --clean --if-exists \
    > "${WORK_DIR}/postgres-all.sql" 2>&1; then
  PG_SIZE=$(du -sh "${WORK_DIR}/postgres-all.sql" | cut -f1)
  echo "[backup] PostgreSQL dump complete (${PG_SIZE})"
  SUCCESSES=$((SUCCESSES + 1))
else
  echo "[backup] ERROR: PostgreSQL dump failed" >&2
  FAILURES=$((FAILURES + 1))
fi

# ---- Redis: trigger BGSAVE and copy dump ----
echo "[backup] Triggering Redis BGSAVE..."
if docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE 2>&1 | grep -v "Warning:"; then
  # Wait for BGSAVE to complete (max 30 seconds)
  for i in $(seq 1 30); do
    BG_STATUS=$(docker exec homelab-redis redis-cli -a "${REDIS_PASSWORD}" INFO persistence 2>&1 | grep rdb_bgsave_in_progress | tr -d '\r')
    if echo "$BG_STATUS" | grep -q "rdb_bgsave_in_progress:0"; then
      break
    fi
    sleep 1
  done
  # Copy the RDB file
  if docker cp homelab-redis:/data/dump.rdb "${WORK_DIR}/redis-dump.rdb" 2>&1; then
    REDIS_SIZE=$(du -sh "${WORK_DIR}/redis-dump.rdb" | cut -f1)
    echo "[backup] Redis dump complete (${REDIS_SIZE})"
    SUCCESSES=$((SUCCESSES + 1))
  else
    echo "[backup] ERROR: Redis RDB copy failed" >&2
    FAILURES=$((FAILURES + 1))
  fi
else
  echo "[backup] ERROR: Redis BGSAVE failed" >&2
  FAILURES=$((FAILURES + 1))
fi

# ---- MariaDB: mariadb-dump all databases ----
echo "[backup] Dumping MariaDB (all databases)..."
if docker exec homelab-mariadb mariadb-dump \
    -u root -p"${MARIADB_ROOT_PASSWORD}" \
    --all-databases --single-transaction --routines --triggers \
    > "${WORK_DIR}/mariadb-all.sql" 2>&1; then
  MARIA_SIZE=$(du -sh "${WORK_DIR}/mariadb-all.sql" | cut -f1)
  echo "[backup] MariaDB dump complete (${MARIA_SIZE})"
  SUCCESSES=$((SUCCESSES + 1))
else
  echo "[backup] ERROR: MariaDB dump failed" >&2
  FAILURES=$((FAILURES + 1))
fi

# ---- Check if any backup succeeded ----
if [ "$SUCCESSES" -eq 0 ]; then
  echo "[backup] FATAL: All backup engines failed. No archive created." >&2
  rm -rf "$WORK_DIR"
  exit 1
fi

# ---- Compress ----
ARCHIVE="${BACKUP_DIR}/homelab-db-backup-${TIMESTAMP}.tar.gz"
echo "[backup] Compressing to ${ARCHIVE}..."
tar -czf "$ARCHIVE" -C "$WORK_DIR" .
ARCHIVE_SIZE=$(du -sh "$ARCHIVE" | cut -f1)

# Clean up temp dir
rm -rf "$WORK_DIR"

echo "[backup] Archive created: ${ARCHIVE} (${ARCHIVE_SIZE})"

# ---- Retention: prune backups older than N days ----
echo "[backup] Pruning backups older than ${BACKUP_RETENTION_DAYS} days..."
PRUNED=$(find "$BACKUP_DIR" -name "homelab-db-backup-*.tar.gz" -mtime "+${BACKUP_RETENTION_DAYS}" -print -delete 2>/dev/null | wc -l | tr -d ' ')
echo "[backup] Pruned ${PRUNED} old backup(s)"

# ---- Summary ----
TOTAL_BACKUPS=$(find "$BACKUP_DIR" -name "homelab-db-backup-*.tar.gz" 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "[backup] === Backup Complete ==="
echo "[backup] Archive: ${ARCHIVE}"
echo "[backup] Size: ${ARCHIVE_SIZE}"
echo "[backup] Engines: ${SUCCESSES}/3 succeeded, ${FAILURES}/3 failed"
echo "[backup] Total backups on disk: ${TOTAL_BACKUPS}"
echo "[backup] Retention: ${BACKUP_RETENTION_DAYS} days"

# Exit with warning code if partial failure
if [ "$FAILURES" -gt 0 ]; then
  echo "[backup] WARNING: ${FAILURES} engine(s) failed — check logs above" >&2
  exit 2
fi
