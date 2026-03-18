#!/usr/bin/env bash
# =============================================================================
# backup.sh — 3-2-1 备份策略统一入口
#
# Usage:
#   backup.sh --target <stack|all> [options]
#
# Options:
#   --target all          备份所有 stack 数据卷
#   --target media        仅备份媒体栈
#   --target databases    仅备份数据库栈
#   --dry-run             显示将备份的内容，不实际执行
#   --restore <backup_id> 从指定备份恢复
#   --list                列出所有备份
#   --verify              验证备份完整性
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }

BACKUP_DIR="${BACKUP_DIR:-/opt/homelab/backups}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"  # local|s3|b2|sftp|r2
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
NOTIFY_SCRIPT="${SCRIPT_DIR}/notify.sh"
DRY_RUN=false
TARGET="all"
ACTION="backup"
RESTORE_ID=""

# ── Parse Args ───────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)   TARGET="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --restore)  ACTION="restore"; RESTORE_ID="$2"; shift 2 ;;
    --list)     ACTION="list"; shift ;;
    --verify)   ACTION="verify"; shift ;;
    *)          echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Helpers ──────────────────────────────────────────────────────────────────

log()   { echo "[backup][$(date +%H:%M:%S)] $*"; }
ok()    { echo "[backup][$(date +%H:%M:%S)] ✅ $*"; }
fail()  { echo "[backup][$(date +%H:%M:%S)] ❌ $*"; }
notify() {
  local title="$1" msg="$2" prio="${3:-3}"
  [[ -x "$NOTIFY_SCRIPT" ]] && "$NOTIFY_SCRIPT" homelab-backups "$title" "$msg" "$prio" || true
}

get_volumes() {
  local stack="$1"
  docker compose -f "${SCRIPT_DIR}/../stacks/${stack}/docker-compose.yml" config --volumes 2>/dev/null || true
}

get_stacks() {
  if [[ "$TARGET" == "all" ]]; then
    find "${SCRIPT_DIR}/../stacks" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;
  else
    echo "$TARGET"
  fi
}

# ── Backup Target Handlers ───────────────────────────────────────────────────

upload_backup() {
  local archive="$1"
  local remote_path="backups/$(basename "$archive")"

  case "$BACKUP_TARGET" in
    local)
      log "Local backup only — no upload"
      ;;
    s3)
      log "Uploading to S3/MinIO..."
      mc cp "$archive" "minio/${remote_path}" && ok "S3 upload" || fail "S3 upload"
      ;;
    b2)
      log "Uploading to Backblaze B2..."
      b2 upload-file "${B2_BUCKET:-homelab-backups}" "$archive" "$remote_path" && ok "B2 upload" || fail "B2 upload"
      ;;
    sftp)
      log "Uploading via SFTP..."
      scp "$archive" "${SFTP_TARGET:-backup@remote:/backups}/${remote_path}" && ok "SFTP upload" || fail "SFTP upload"
      ;;
    r2)
      log "Uploading to Cloudflare R2..."
      aws s3 cp "$archive" "s3://${R2_BUCKET:-homelab-backups}/${remote_path}" \
        --endpoint-url "${R2_ENDPOINT}" && ok "R2 upload" || fail "R2 upload"
      ;;
    *)
      fail "Unknown BACKUP_TARGET: $BACKUP_TARGET"
      ;;
  esac
}

# ── Actions ──────────────────────────────────────────────────────────────────

do_backup() {
  local backup_name="backup-${TARGET}-${TIMESTAMP}"
  local backup_path="${BACKUP_DIR}/${backup_name}"
  local errors=0

  mkdir -p "$backup_path"
  log "Starting backup: target=${TARGET}, dest=${backup_path}"

  # Database backup (if databases stack or all)
  if [[ "$TARGET" == "all" || "$TARGET" == "databases" ]]; then
    log "Backing up databases..."
    if $DRY_RUN; then
      log "[DRY-RUN] Would run pg_dumpall + redis BGSAVE"
    else
      # PostgreSQL
      if docker ps --format '{{.Names}}' | grep -q '^postgres$'; then
        docker exec postgres pg_dumpall -U postgres > "${backup_path}/pg_dumpall.sql" 2>&1 \
          && ok "PostgreSQL dump" || { fail "PostgreSQL dump"; ((errors++)); }
      fi
      # Redis
      if docker ps --format '{{.Names}}' | grep -q '^redis$'; then
        docker exec redis redis-cli -a "${REDIS_PASSWORD:-changeme}" BGSAVE >/dev/null 2>&1
        sleep 2
        docker cp redis:/data/dump.rdb "${backup_path}/redis-dump.rdb" 2>&1 \
          && ok "Redis dump" || { fail "Redis dump"; ((errors++)); }
      fi
    fi
  fi

  # Volume backups
  for stack in $(get_stacks); do
    log "Backing up stack: ${stack}"
    if $DRY_RUN; then
      log "[DRY-RUN] Would backup volumes for stack: ${stack}"
      get_volumes "$stack" | while read -r vol; do
        log "  [DRY-RUN] Volume: ${vol}"
      done
      continue
    fi

    local stack_dir="${backup_path}/${stack}"
    mkdir -p "$stack_dir"

    # Backup each named volume
    docker compose -f "${SCRIPT_DIR}/../stacks/${stack}/docker-compose.yml" config --volumes 2>/dev/null | while read -r vol; do
      local full_vol="${stack}_${vol}"
      if docker volume inspect "$full_vol" &>/dev/null; then
        docker run --rm -v "${full_vol}:/data:ro" -v "${stack_dir}:/backup" \
          alpine tar czf "/backup/${vol}.tar.gz" -C /data . 2>&1 \
          && ok "Volume ${full_vol}" || { fail "Volume ${full_vol}"; ((errors++)); }
      fi
    done
  done

  if $DRY_RUN; then
    log "[DRY-RUN] Complete. No changes made."
    return 0
  fi

  # Compress
  log "Compressing..."
  cd "$BACKUP_DIR"
  tar czf "${backup_name}.tar.gz" "${backup_name}/"
  rm -rf "$backup_path"

  local archive="${BACKUP_DIR}/${backup_name}.tar.gz"
  local size=$(du -h "$archive" | cut -f1)
  ok "Archive: ${archive} (${size})"

  # Upload
  upload_backup "$archive"

  # Retention
  log "Applying retention: ${RETENTION_DAYS} days"
  find "$BACKUP_DIR" -name "backup-*.tar.gz" -mtime "+${RETENTION_DAYS}" -delete
  ok "Retention applied"

  # Notify
  if [[ $errors -eq 0 ]]; then
    notify "Backup Complete" "Target: ${TARGET} | Size: ${size} | Archive: ${backup_name}.tar.gz" 3
    ok "Backup complete: ${backup_name}.tar.gz (${size})"
  else
    notify "Backup Partial" "Target: ${TARGET} | ${errors} errors | Size: ${size}" 4
    fail "Backup completed with ${errors} errors"
  fi
}

do_list() {
  log "Available backups in ${BACKUP_DIR}:"
  echo ""
  printf "%-45s %8s %s\n" "ARCHIVE" "SIZE" "DATE"
  printf "%-45s %8s %s\n" "-------" "----" "----"
  find "$BACKUP_DIR" -name "backup-*.tar.gz" -printf "%f %s %Tc\n" 2>/dev/null | \
    sort -r | while read -r name size date; do
      local hr_size=$(numfmt --to=iec "$size" 2>/dev/null || echo "${size}B")
      printf "%-45s %8s %s\n" "$name" "$hr_size" "$date"
    done
  echo ""
}

do_verify() {
  log "Verifying backups in ${BACKUP_DIR}..."
  local count=0 ok_count=0 fail_count=0
  for archive in "${BACKUP_DIR}"/backup-*.tar.gz; do
    [[ -f "$archive" ]] || continue
    ((count++))
    if tar tzf "$archive" &>/dev/null; then
      ok "$(basename "$archive")"
      ((ok_count++))
    else
      fail "$(basename "$archive") — CORRUPT"
      ((fail_count++))
    fi
  done
  echo ""
  log "Verified: ${count} archives, ${ok_count} OK, ${fail_count} failed"
}

do_restore() {
  if [[ -z "$RESTORE_ID" ]]; then
    fail "No backup_id specified. Use --list to see available backups."
    exit 1
  fi

  local archive="${BACKUP_DIR}/${RESTORE_ID}"
  [[ "$RESTORE_ID" != *.tar.gz ]] && archive="${archive}.tar.gz"

  if [[ ! -f "$archive" ]]; then
    fail "Backup not found: ${archive}"
    exit 1
  fi

  log "⚠️  RESTORING from: $(basename "$archive")"
  log "⚠️  This will OVERWRITE current data. Press Ctrl+C to abort (5s)..."
  sleep 5

  local restore_dir="${BACKUP_DIR}/restore-tmp"
  rm -rf "$restore_dir"
  mkdir -p "$restore_dir"

  tar xzf "$archive" -C "$restore_dir"
  local backup_root=$(ls "$restore_dir")

  # Restore PostgreSQL
  local pg_dump="${restore_dir}/${backup_root}/pg_dumpall.sql"
  if [[ -f "$pg_dump" ]]; then
    log "Restoring PostgreSQL..."
    docker exec -i postgres psql -U postgres < "$pg_dump" && ok "PostgreSQL restored" || fail "PostgreSQL restore"
  fi

  # Restore Redis
  local redis_dump="${restore_dir}/${backup_root}/redis-dump.rdb"
  if [[ -f "$redis_dump" ]]; then
    log "Restoring Redis..."
    docker stop redis 2>/dev/null || true
    docker cp "$redis_dump" redis:/data/dump.rdb
    docker start redis
    ok "Redis restored"
  fi

  # Restore volumes
  for stack_dir in "${restore_dir}/${backup_root}"/*/; do
    local stack=$(basename "$stack_dir")
    [[ "$stack" == "." ]] && continue
    log "Restoring stack: ${stack}"
    for vol_archive in "${stack_dir}"*.tar.gz; do
      [[ -f "$vol_archive" ]] || continue
      local vol=$(basename "$vol_archive" .tar.gz)
      local full_vol="${stack}_${vol}"
      if docker volume inspect "$full_vol" &>/dev/null; then
        docker run --rm -v "${full_vol}:/data" -v "$(dirname "$vol_archive"):/backup:ro" \
          alpine sh -c "rm -rf /data/* && tar xzf /backup/$(basename "$vol_archive") -C /data" \
          && ok "Volume ${full_vol}" || fail "Volume ${full_vol}"
      else
        log "Skipping ${full_vol} — volume doesn't exist"
      fi
    done
  done

  rm -rf "$restore_dir"
  notify "Restore Complete" "Restored from: $(basename "$archive")" 4
  ok "Restore complete from: $(basename "$archive")"
}

# ── Main ─────────────────────────────────────────────────────────────────────

case "$ACTION" in
  backup)  do_backup ;;
  list)    do_list ;;
  verify)  do_verify ;;
  restore) do_restore ;;
esac
