#!/usr/bin/env bash
# =============================================================================
# HomeLab Database Backup Script - ShadowRoot Edition
# Backs up PostgreSQL, Redis, and MariaDB + Auto-rotation (7 days)
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
# Directorio de backups según el estándar del proyecto
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups/databases}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colores para la terminal
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

mkdir -p "$BACKUP_DIR"

backup_postgres() {
  log_info "Backing up PostgreSQL (Multi-tenant)..."
  local file="$BACKUP_DIR/postgres_${TIMESTAMP}.sql.gz"
  # Usamos pg_dumpall para capturar todas las DBs del stack compartido
  docker exec db-postgres pg_dumpall -U "${POSTGRES_USER:-postgres}" | gzip > "$file"
  log_info "PostgreSQL backup: $file"
}

backup_redis() {
  log_info "Backing up Redis..."
  local file="$BACKUP_DIR/redis_${TIMESTAMP}.rdb"
  docker exec db-redis redis-cli -a "${REDIS_PASSWORD}" --no-auth-warning BGSAVE
  sleep 3 # Espera quirúrgica para el dump
  docker cp db-redis:/data/dump.rdb "$file"
  log_info "Redis backup: $file"
}

backup_mariadb() {
  log_info "Backing up MariaDB (Compatibility layer)..."
  local file="$BACKUP_DIR/mariadb_${TIMESTAMP}.sql.gz"
  docker exec db-mariadb mariadb-dump --all-databases -u root -p"${MARIADB_ROOT_PASSWORD}" | gzip > "$file"
  log_info "MariaDB backup: $file"
}

rotate_backups() {
  log_warn "Rotating backups: deleting files older than 7 days..."
  # Requisito 3 del Bounty: "保留最近 7 天" (Mantener últimos 7 días)
  find "$BACKUP_DIR" -type f -mtime +7 -name "*.gz" -delete
  find "$BACKUP_DIR" -type f -mtime +7 -name "*.rdb" -delete
}

case "${1:---all}" in
  --postgres) backup_postgres ;;
  --redis)    backup_redis ;;
  --mariadb)  backup_mariadb ;;
  --all)
    backup_postgres
    backup_redis
    backup_mariadb
    rotate_backups
    log_info "✅ All backups completed and rotated in $BACKUP_DIR"
    ;;
  *) echo "Usage: $0 [--postgres|--redis|--mariadb|--all]"; exit 1 ;;
esac

