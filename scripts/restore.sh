#!/usr/bin/env bash
# =============================================================================
# HomeLab Restore Script
# Restores Docker volumes, configs, and databases from backup.
# Usage: ./restore.sh /path/to/backup_dir
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <backup_dir>"
  echo "  backup_dir: Path to timestamped backup directory (e.g. /opt/homelab-backups/20260101_120000)"
  exit 1
fi

BACKUP_PATH="$1"
if [[ ! -d "$BACKUP_PATH" ]]; then
  echo "ERROR: Backup directory not found: $BACKUP_PATH"
  exit 1
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[restore]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[restore]${NC} $*"; }
log_error() { echo -e "${RED}[restore]${NC} $*" >&2; }

# --- Confirm ---
echo -e "${YELLOW}WARNING: This will overwrite existing data!${NC}"
echo "Backup source: $BACKUP_PATH"
read -rp "Continue? (yes/no): " confirm
[[ "$confirm" == "yes" ]] || { log_info "Aborted."; exit 0; }

# --- Restore Docker volumes ---
restore_volumes() {
  log_info "Restoring Docker volumes..."
  for archive in "$BACKUP_PATH"/vol_*.tar.gz; do
    [[ -f "$archive" ]] || continue
    local vol_name
    vol_name=$(basename "$archive" | sed 's/^vol_//;s/\.tar.gz$//')
    log_info "  Restoring volume: $vol_name"
    docker run --rm \
      -v "${vol_name}:/data" \
      -v "$BACKUP_PATH:/backup:ro" \
      alpine:3.19 \
      sh -c "rm -rf /data/* && tar xzf /backup/$(basename "$archive") -C /data" 2>/dev/null || \
      log_warn "  Failed to restore volume: $vol_name"
  done
}

# --- Restore configs ---
restore_configs() {
  if [[ -f "$BACKUP_PATH/configs.tar.gz" ]]; then
    log_info "Restoring configs..."
    tar xzf "$BACKUP_PATH/configs.tar.gz" -C "$BASE_DIR" || \
      log_warn "Config restore failed"
  fi
}

# --- Restore PostgreSQL ---
restore_postgres() {
  if [[ -f "$BACKUP_PATH/postgresql_all.sql" ]]; then
    log_info "Restoring PostgreSQL..."
    if docker ps --format '{{.Names}}' | grep -q 'homelab-postgres'; then
      docker exec -i homelab-postgres psql -U postgres < "$BACKUP_PATH/postgresql_all.sql" 2>/dev/null || \
        log_warn "PostgreSQL restore failed"
    else
      log_warn "PostgreSQL container not running, skipping"
    fi
  fi
}

# --- Restore MariaDB ---
restore_mariadb() {
  if [[ -f "$BACKUP_PATH/mysql_all.sql" ]]; then
    log_info "Restoring MariaDB..."
    if docker ps --format '{{.Names}}' | grep -q 'homelab-mariadb'; then
      docker exec -i homelab-mariadb mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" < "$BACKUP_PATH/mysql_all.sql" 2>/dev/null || \
        log_warn "MariaDB restore failed"
    else
      log_warn "MariaDB container not running, skipping"
    fi
  fi
}

# --- Main ---
log_info "Starting restore from: $BACKUP_PATH"

# Source env if available
[[ -f "$BASE_DIR/config/.env" ]] && source "$BASE_DIR/config/.env"

restore_configs
restore_volumes
restore_postgres
restore_mariadb

log_info "Restore complete!"
log_info "Restart services: cd $BASE_DIR && ./scripts/stack-manager.sh restart-all"
