#!/bin/bash
# =============================================================================
# PostgreSQL Backup Script — GPG-encrypted, automated
# Usage: ./backup-postgres.sh [days-to-retain]
# =============================================================================
set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab/backups/postgres}"
RETENTION_DAYS="${1:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/postgres_${TIMESTAMP}.sql.gz.gpg"
LOG_FILE="${BACKUP_DIR}/backup.log"

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../.env"
if [[ -f "$ENV_FILE" ]]; then
    set -a; source "$ENV_FILE"; set +a
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# GPG encryption passphrase from environment
if [[ -z "${POSTGRES_BACKUP_PASSWORD:-}" ]]; then
    echo "[$(date)] ERROR: POSTGRES_BACKUP_PASSWORD not set" >> "$LOG_FILE"
    exit 1
fi

# Perform backup
echo "[$(date)] Starting PostgreSQL backup..." >> "$LOG_FILE"
docker exec homelab-postgres pg_dump -U "${POSTGRES_ROOT_USER:-postgres}" \
    --exclude-table='spatial_ref_sys' \
    --exclude-table='geometry_columns' \
    -F c -b | \
    gzip | \
    gpg --batch --yes --passphrase "$POSTGRES_BACKUP_PASSWORD" \
        --pinentry-mode loopback \
        --symmetric --cipher-algo AES256 -o "$BACKUP_FILE" 2>&1

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "[$(date)] Backup completed: $BACKUP_FILE ($BACKUP_SIZE)" >> "$LOG_FILE"

# Verify backup
if gpg --batch --yes --passphrase "$POSTGRES_BACKUP_PASSWORD" \
    --pinentry-mode loopback \
    --decrypt "$BACKUP_FILE" 2>/dev/null | zcat > /dev/null; then
    echo "[$(date)] Backup verification: OK" >> "$LOG_FILE"
else
    echo "[$(date)] ERROR: Backup verification failed" >> "$LOG_FILE"
    exit 1
fi

# Clean old backups
find "$BACKUP_DIR" -name "postgres_*.sql.gz.gpg" -mtime +$RETENTION_DAYS -delete
echo "[$(date)] Old backups (>${RETENTION_DAYS} days) cleaned up" >> "$LOG_FILE"

# Create symlink to latest
ln -sf "$(basename "$BACKUP_FILE")" "${BACKUP_DIR}/latest.sql.gz.gpg"

echo "[$(date)] PostgreSQL backup completed successfully" >> "$LOG_FILE"
