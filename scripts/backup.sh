#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup — Docker volumes + configs 全量备份
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."
ENV_FILE="$BASE_DIR/config/.env"

[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error() { echo -e "${RED}[backup]${NC} $*" >&2; }

mkdir -p "$BACKUP_PATH"

# 备份 Docker volumes
backup_volumes() {
  log_info "Backing up Docker volumes..."
  local volumes
  volumes=$(docker volume ls --format '{{.Name}}' | grep -v '^[a-f0-9]\{64\}$' || true)
  while IFS= read -r vol; do
    [[ -z "$vol" ]] && continue
    log_info "  Volume: $vol"
    docker run --rm \
      -v "${vol}:/data:ro" \
      -v "$BACKUP_PATH:/backup" \
      alpine:3.19 \
      tar czf "/backup/vol_${vol}.tar.gz" -C /data . 2>/dev/null || \
      log_warn "  Failed to backup volume: $vol"
  done <<< "$volumes"
}

# 备份配置文件
backup_configs() {
  log_info "Backing up configs..."
  tar czf "$BACKUP_PATH/configs.tar.gz" \
    -C "$BASE_DIR" \
    --exclude='stacks/*/data' \
    config/ stacks/ scripts/ 2>/dev/null || true
}

# 备份数据库
backup_databases() {
  log_info "Backing up databases..."

  # PostgreSQL
  if docker ps --format '{{.Names}}' | grep -q 'postgres\|postgresql'; then
    local pg_container
    pg_container=$(docker ps --format '{{.Names}}' | grep -E 'postgres|postgresql' | head -1)
    local pg_pass
    pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep POSTGRES_PASSWORD | cut -d= -f2 | head -1)
    docker exec "$pg_container" \
      sh -c "PGPASSWORD='$pg_pass' pg_dumpall -U postgres" \
      > "$BACKUP_PATH/postgresql_all.sql" 2>/dev/null || \
      log_warn "PostgreSQL backup failed"
  fi

  # MariaDB/MySQL
  if docker ps --format '{{.Names}}' | grep -q 'mariadb\|mysql'; then
    local mysql_container
    mysql_container=$(docker ps --format '{{.Names}}' | grep -E 'mariadb|mysql' | head -1)
    local mysql_pass
    mysql_pass=$(docker inspect "$mysql_container" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep MYSQL_ROOT_PASSWORD | cut -d= -f2 | head -1)
    docker exec "$mysql_container" \
      sh -c "mysqldump -u root -p'$mysql_pass' --all-databases" \
      > "$BACKUP_PATH/mysql_all.sql" 2>/dev/null || \
      log_warn "MySQL backup failed"
  fi
}

# 清理旧备份
cleanup_old() {
  log_info "Cleaning backups older than ${RETENTION_DAYS} days..."
  find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true
}

# 生成备份摘要
generate_summary() {
  local total_size
  total_size=$(du -sh "$BACKUP_PATH" 2>/dev/null | cut -f1)
  log_info "Backup complete: $BACKUP_PATH ($total_size)"
  ls -lh "$BACKUP_PATH/"
}

log_info "Starting backup — $TIMESTAMP"
backup_configs
backup_volumes
backup_databases
cleanup_old
generate_summary
