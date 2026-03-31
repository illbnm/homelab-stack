#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup Script — 3-2-1 Backup Strategy
# Supports: Local, S3 (MinIO), Backblaze B2, SFTP, Cloudflare R2
#
# Usage:
#   backup.sh --target all|media [--dry-run] [--restore <backup_id>] [--list] [--verify]
#
# Environment (.env):
#   BACKUP_TARGET=s3|b2|sftp|local       Backup destination
#   BACKUP_DIR=/opt/homelab-backups       Local backup root
#   RETENTION_DAYS=7                      Backup retention
#   NTFY_TOPIC=                           ntfy notification topic
#   NTFY_HOST=http://ntfy.example.com     ntfy server URL
#
# S3/MinIO:
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_ENDPOINT, AWS_BUCKET, AWS_REGION
#
# Backblaze B2:
#   B2_ACCOUNT_ID, B2_ACCOUNT_KEY, B2_BUCKET, B2_ENDPOINT (optional)
#
# SFTP:
#   SFTP_HOST, SFTP_PORT, SFTP_USER, SFTP_PASSWORD or SFTP_KEY
#
# Cloudflare R2:
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_ENDPOINT (R2 endpoint), AWS_BUCKET, AWS_REGION=auto
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"
ENV_FILE="$BASE_DIR/config/.env"

# Load environment
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# ---- Defaults ----
BACKUP_TARGET="${BACKUP_TARGET:-local}"
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
NTFY_HOST="${NTFY_HOST:-http://ntfy}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab-backup}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_ID="${TIMESTAMP}"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_ID"

# ---- CLI Args ----
DRY_RUN=false
RESTORE_ID=""
LIST_MODE=false
VERIFY_MODE=false
TARGET_TYPE="all"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)     TARGET_TYPE="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --restore)    RESTORE_ID="$2"; shift 2 ;;
    --list)       LIST_MODE=true; shift ;;
    --verify)     VERIFY_MODE=true; shift ;;
    *)            echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ---- Colors ----
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error() { echo -e "${RED}[backup]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[backup]${NC} $*"; }

# ---- ntfy notification ----
notify() {
  local status="$1"   # success | failure
  local message="$2"
  local priority="${3:-normal}"
  local tags

  if [[ "$status" == "success" ]]; then
    tags="white_check_mark"
  else
    tags="x"
  fi

  curl -s -o /dev/null \
    --data-urlencode "topic=${NTFY_TOPIC}" \
    --data-urlencode "message=${message}" \
    --data-urlencode "priority=${priority}" \
    --data-urlencode "tags=${tags}" \
    "${NTFY_HOST}/v1/send" 2>/dev/null || true
}

# ---- Trap for failures ----
notify_on_exit() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    log_error "Backup failed with exit code $exit_code"
    notify "failure" "Backup FAILED for ${TARGET_TYPE} at ${TIMESTAMP}. Check logs."
    exit $exit_code
  fi
}
trap 'notify_on_exit' ERR

# =============================================================================
# HELPER: resolve backup target path
# =============================================================================
get_remote_path() {
  local backup_file="$1"
  case "$BACKUP_TARGET" in
    s3|b2|r2)
      echo "s3://${AWS_BUCKET:-homelab-backups}/${backup_file}"
      ;;
    sftp)
      echo "${SFTP_REMOTE_DIR:-/backups}/${backup_file}"
      ;;
    local|*)
      echo "${BACKUP_DIR}/${backup_file}"
      ;;
  esac
}

# =============================================================================
# HELPER: upload file to backup target
# =============================================================================
upload_to_target() {
  local src="$1"
  local dest="$2"

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] Would upload: $src → $dest"
    return 0
  fi

  case "$BACKUP_TARGET" in
    s3|b2|r2)
      AWS_PAGER="" aws s3 cp "$src" "$dest" --storage-class STANDARD_IA 2>/dev/null || \
      AWS_PAGER="" aws s3 cp "$src" "$dest" 2>/dev/null
      ;;
    sftp)
      sftp_batch_mode "${SFTP_USER}@${SFTP_HOST}:${dest}" <<< "put $src"
      ;;
    local|*)
      mkdir -p "$(dirname "$dest")"
      cp "$src" "$dest"
      ;;
  esac
}

# =============================================================================
# HELPER: download from backup target
# =============================================================================
download_from_target() {
  local src="$1"
  local dest="$2"

  case "$BACKUP_TARGET" in
    s3|b2|r2)
      AWS_PAGER="" aws s3 cp "$src" "$dest" 2>/dev/null
      ;;
    sftp)
      sftp_batch_mode "${SFTP_USER}@${SFTP_HOST}:${src}" "$dest"
      ;;
    local|*)
      cp "$src" "$dest"
      ;;
  esac
}

# =============================================================================
# HELPER: list backups at target
# =============================================================================
list_backups_at_target() {
  case "$BACKUP_TARGET" in
    s3|b2|r2)
      AWS_PAGER="" aws s3 ls "${AWS_BUCKET:-homelab-backups}/" 2>/dev/null | grep "^20" | awk '{print $4, $1, $2}' || true
      ;;
    sftp)
      sftp_batch_mode "${SFTP_USER}@${SFTP_HOST}:${SFTP_REMOTE_DIR:-/backups}" <<< "ls -la" 2>/dev/null || true
      ;;
    local|*)
      ls -lt "$BACKUP_DIR/" 2>/dev/null | grep "^d" | head -20 || true
      ;;
  esac
}

# =============================================================================
# HELPER: sync directory to target
# =============================================================================
sync_to_target() {
  local src_dir="$1"
  local dest_prefix="$2"

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] Would sync: $src_dir → $dest_prefix"
    return 0
  fi

  case "$BACKUP_TARGET" in
    s3|b2|r2)
      AWS_PAGER="" aws s3 sync "$src_dir" "${AWS_BUCKET:-homelab-backups}/${dest_prefix}/" --storage-class STANDARD_IA 2>/dev/null || \
      AWS_PAGER="" aws s3 sync "$src_dir" "${AWS_BUCKET:-homelab-backups}/${dest_prefix}/" 2>/dev/null
      ;;
    sftp)
      sftp -r "${SFTP_USER}@${SFTP_HOST}:${SFTP_REMOTE_DIR:-/backups}/${dest_prefix}/" <<< "mkdir ${dest_prefix}" 2>/dev/null || true
      scp -r "$src_dir/" "${SFTP_USER}@${SFTP_HOST}:${SFTP_REMOTE_DIR:-/backups}/${dest_prefix}/" 2>/dev/null
      ;;
    local|*)
      mkdir -p "${BACKUP_DIR}/${dest_prefix}"
      rsync -av "$src_dir/" "${BACKUP_DIR}/${dest_prefix}/" 2>/dev/null || cp -r "$src_dir/" "${BACKUP_DIR}/${dest_prefix}/"
      ;;
  esac
}

# =============================================================================
# Helper: sftp batch mode (password or key)
# =============================================================================
sftp_batch_mode() {
  local dest="$1"
  if [[ -n "${SFTP_KEY:-}" ]]; then
    echo -e "$2" | sftp -i "$SFTP_KEY" -o StrictHostKeyChecking=no "$dest" 2>/dev/null
  else
    echo -e "$2" | sftp -o StrictHostKeyChecking=no "$dest" 2>/dev/null
  fi
}

# =============================================================================
# HELPER: verify backup integrity
# =============================================================================
verify_backup() {
  local backup_id="$1"
  local remote_path
  remote_path=$(get_remote_path "")
  log_step "Verifying backup: $backup_id"

  case "$BACKUP_TARGET" in
    s3|b2|r2)
      log_info "Checking S3 metadata..."
      AWS_PAGER="" aws s3 ls "${AWS_BUCKET:-homelab-backups}/${backup_id}/" 2>/dev/null | head -5
      ;;
    local|*)
      if [[ -d "${BACKUP_DIR}/${backup_id}" ]]; then
        log_info "Backup exists locally: ${BACKUP_DIR}/${backup_id}"
        local size
        size=$(du -sh "${BACKUP_DIR}/${backup_id}" 2>/dev/null | cut -f1)
        log_info "Total size: $size"
        ls -lh "${BACKUP_DIR}/${backup_id}/" 2>/dev/null | head -20
      else
        log_error "Backup not found: $backup_id"
        return 1
      fi
      ;;
  esac

  log_info "Verification complete for: $backup_id"
}

# =============================================================================
# LIST MODE
# =============================================================================
do_list() {
  log_step "Available backups:"
  echo ""
  list_backups_at_target
  echo ""
  if [[ "$BACKUP_TARGET" == "local" ]]; then
    log_info "Local backup dir: $BACKUP_DIR"
  fi
}

# =============================================================================
# VERIFY MODE
# =============================================================================
do_verify() {
  if [[ -z "$RESTORE_ID" ]]; then
    log_error "--verify requires --restore <backup_id>"
    exit 1
  fi
  verify_backup "$RESTORE_ID"
}

# =============================================================================
# RESTORE MODE
# =============================================================================
do_restore() {
  if [[ -z "$RESTORE_ID" ]]; then
    log_error "--restore requires a backup_id argument"
    exit 1
  fi

  log_step "Starting restore from backup: $RESTORE_ID"
  local tmp_restore="/tmp/homelab-restore-${RESTORE_ID}"
  mkdir -p "$tmp_restore"

  # Download/rsync backup to temp dir
  case "$BACKUP_TARGET" in
    s3|b2|r2)
      log_info "Downloading from S3..."
      AWS_PAGER="" aws s3 sync "${AWS_BUCKET:-homelab-backups}/${RESTORE_ID}/" "$tmp_restore/" 2>/dev/null
      ;;
    sftp)
      log_info "Downloading from SFTP..."
      sftp -r "${SFTP_USER}@${SFTP_HOST}:${SFTP_REMOTE_DIR:-/backups}/${RESTORE_ID}/" "$tmp_restore/" 2>/dev/null
      ;;
    local|*)
      log_info "Copying from local..."
      cp -r "${BACKUP_DIR}/${RESTORE_ID}/" "$tmp_restore/"
      ;;
  esac

  # Restore configs
  if [[ -f "$tmp_restore/configs.tar.gz" ]]; then
    log_info "Restoring configs..."
    tar xzf "$tmp_restore/configs.tar.gz" -C "$BASE_DIR" 2>/dev/null || true
  fi

  # Restore databases
  for sql_backup in "$tmp_restore"/*.sql*; do
    [[ -f "$sql_backup" ]] || continue
    local fname
    fname=$(basename "$sql_backup")

    if [[ "$fname" == postgresql* ]]; then
      log_info "Restoring PostgreSQL..."
      docker exec homelab-postgres psql -U "${POSTGRES_ROOT_USER:-postgres}" < <(gunzip -c "$sql_backup") 2>/dev/null || \
      log_warn "PostgreSQL restore failed — check credentials"
    elif [[ "$fname" == mysql* ]] || [[ "$fname" == mariadb* ]]; then
      log_info "Restoring MariaDB..."
      docker exec homelab-mariadb mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" < <(gunzip -c "$sql_backup") 2>/dev/null || \
      log_warn "MariaDB restore failed — check credentials"
    fi
  done

  # Restore Docker volumes
  for vol_tar in "$tmp_restore"/vol_*.tar.gz; do
    [[ -f "$vol_tar" ]] || continue
    local vol_name
    vol_name=$(basename "$vol_tar" | sed 's/^vol_//;s/\.tar\.gz$//')
    log_info "Restoring volume: $vol_name"
    # Create volume if not exists
    docker volume create "$vol_name" >/dev/null 2>&1 || true
    docker run --rm \
      -v "${vol_name}:/data" \
      -v "$tmp_restore:/backup:ro" \
      alpine:3.19 \
      sh -c "rm -rf /data/* && tar xzf /backup/vol_${vol_name}.tar.gz -C /data" 2>/dev/null || \
      log_warn "Volume restore failed: $vol_name"
  done

  rm -rf "$tmp_restore"
  log_info "Restore complete for backup: $RESTORE_ID"
  notify "success" "Restore COMPLETE for ${RESTORE_ID}. Please verify all services."
}

# =============================================================================
# BACKUP MODE
# =============================================================================
do_backup() {
  log_step "=========================================="
  log_step "  HomeLab Backup — ${TARGET_TYPE} @ ${TIMESTAMP}"
  log_step "  Target: ${BACKUP_TARGET}"
  log_step "=========================================="

  mkdir -p "$BACKUP_PATH"

  # ---- Docker volumes backup ----
  backup_volumes

  # ---- Configs backup ----
  backup_configs

  # ---- Databases backup ----
  backup_databases

  # ---- Media volumes (if requested) ----
  if [[ "$TARGET_TYPE" == "all" ]] || [[ "$TARGET_TYPE" == "media" ]]; then
    backup_media_volumes
  fi

  # ---- Compress & upload ----
  log_info "Packaging backup..."
  cd "$BACKUP_PATH"
  tar czf "${BACKUP_ID}.tar.gz" ./* 2>/dev/null || true

  # Upload to target
  log_info "Uploading to ${BACKUP_TARGET}..."
  local remote_dest
  remote_dest=$(get_remote_path "${BACKUP_ID}.tar.gz")
  upload_to_target "${BACKUP_PATH}.tar.gz" "$remote_dest"

  # Upload manifest
  create_manifest
  upload_to_target "$BACKUP_PATH/manifest.json" "$(get_remote_path "${BACKUP_ID}-manifest.json")"

  # Cleanup
  cleanup_old

  # Summary
  generate_summary

  notify "success" "Backup COMPLETE: ${TARGET_TYPE} — ${BACKUP_ID}. See ${BACKUP_DIR} for details."
}

# =============================================================================
# BACKUP: Docker volumes
# =============================================================================
backup_volumes() {
  log_info "Backing up Docker volumes..."
  local volumes
  volumes=$(docker volume ls --format '{{.Name}}' | grep -v '^[a-f0-9]\{64\}$' || true)
  while IFS= read -r vol; do
    [[ -z "$vol" ]] && continue
    log_info "  Volume: $vol"
    if [[ "$DRY_RUN" == true ]]; then
      log_info "    [DRY-RUN] Would tar volume: $vol"
      continue
    fi
    docker run --rm \
      -v "${vol}:/data:ro" \
      -v "$BACKUP_PATH:/backup" \
      alpine:3.19 \
      tar czf "/backup/vol_${vol}.tar.gz" -C /data . 2>/dev/null || \
      log_warn "  Failed to backup volume: $vol"
  done <<< "$volumes"
}

# =============================================================================
# BACKUP: Media volumes
# =============================================================================
backup_media_volumes() {
  log_info "Backing up media volumes..."
  local media_vols="jellyfin-config prowlarr-config sonarr-config radarr-config qbittorrent-config"
  for vol in $media_vols; do
    if docker volume ls --format '{{.Name}}' | grep -q "^${vol}$"; then
      log_info "  Media volume: $vol"
      if [[ "$DRY_RUN" == true ]]; then
        log_info "    [DRY-RUN] Would tar volume: $vol"
        continue
      fi
      docker run --rm \
        -v "${vol}:/data:ro" \
        -v "$BACKUP_PATH:/backup" \
        alpine:3.19 \
        tar czf "/backup/vol_${vol}.tar.gz" -C /data . 2>/dev/null || \
        log_warn "  Failed to backup media volume: $vol"
    fi
  done
}

# =============================================================================
# BACKUP: Configs
# =============================================================================
backup_configs() {
  log_info "Backing up configs..."
  tar czf "$BACKUP_PATH/configs.tar.gz" \
    -C "$BASE_DIR" \
    --exclude='stacks/*/data' \
    --exclude='*.tar.gz' \
    --exclude='.git' \
    config/ stacks/ scripts/ 2>/dev/null || true
}

# =============================================================================
# BACKUP: Databases
# =============================================================================
backup_databases() {
  log_info "Backing up databases..."

  # PostgreSQL
  if docker ps --format '{{.Names}}' | grep -q 'homelab-postgres\|authentik-postgres'; then
    local pg_container
    pg_container=$(docker ps --format '{{.Names}}' | grep -E 'homelab-postgres|authentik-postgres' | head -1)
    local pg_user="${POSTGRES_ROOT_USER:-postgres}"
    local pg_pass="${POSTGRES_PASSWORD:-}"
    if [[ -z "$pg_pass" ]]; then
      pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep POSTGRES_PASSWORD | head -1 | cut -d= -f2)
    fi
    if [[ -n "$pg_pass" ]]; then
      PGPASSWORD="$pg_pass" pg_dumpall -U "$pg_user" -h localhost 2>/dev/null | gzip > "$BACKUP_PATH/postgresql_all.sql.gz" && \
        log_info "  PostgreSQL backup: $(du -sh "$BACKUP_PATH/postgresql_all.sql.gz" | cut -f1)" || \
        log_warn "PostgreSQL backup failed"
    else
      log_warn "PostgreSQL password not found, skipping"
    fi
  fi

  # Redis
  if docker ps --format '{{.Names}}' | grep -q 'homelab-redis\|authentik-redis'; then
    local redis_container
    redis_container=$(docker ps --format '{{.Names}}' | grep -E 'homelab-redis|authentik-redis' | head -1)
    local redis_pass="${REDIS_PASSWORD:-}"
    if [[ -z "$redis_pass" ]]; then
      redis_pass=$(docker inspect "$redis_container" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep REDIS_PASSWORD | head -1 | cut -d= -f2)
    fi
    if [[ -n "$redis_pass" ]]; then
      docker exec "$redis_container" redis-cli -a "$redis_pass" --no-auth-warning BGSAVE >/dev/null 2>&1
      sleep 2
      docker cp "$redis_container:/data/dump.rdb" "$BACKUP_PATH/redis.rdb" 2>/dev/null && \
        log_info "  Redis backup: $(du -sh "$BACKUP_PATH/redis.rdb" | cut -f1)" || \
        log_warn "Redis backup failed"
    fi
  fi

  # MariaDB
  if docker ps --format '{{.Names}}' | grep -q 'homelab-mariadb'; then
    local mysql_pass="${MARIADB_ROOT_PASSWORD:-}"
    if [[ -z "$mysql_pass" ]]; then
      mysql_pass=$(docker inspect homelab-mariadb --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep MARIADB_ROOT_PASSWORD | head -1 | cut -d= -f2)
    fi
    if [[ -n "$mysql_pass" ]]; then
      docker exec homelab-mariadb mariadb-dump --all-databases -u root -p"$mysql_pass" 2>/dev/null | gzip > "$BACKUP_PATH/mariadb_all.sql.gz" && \
        log_info "  MariaDB backup: $(du -sh "$BACKUP_PATH/mariadb_all.sql.gz" | cut -f1)" || \
        log_warn "MariaDB backup failed"
    fi
  fi
}

# =============================================================================
# Create backup manifest
# =============================================================================
create_manifest() {
  cat > "$BACKUP_PATH/manifest.json" <<EOF
{
  "backup_id": "${BACKUP_ID}",
  "timestamp": "${TIMESTAMP}",
  "target_type": "${TARGET_TYPE}",
  "backup_target": "${BACKUP_TARGET}",
  "retention_days": "${RETENTION_DAYS}",
  "hostname": "$(hostname)",
  "files": $(ls -1 "$BACKUP_PATH" | grep -v "manifest.json" | while read f; do echo "\"$f\""; done | paste -sd "," || echo "[]"),
  "created_at": "$(date -Iseconds)"
}
EOF
}

# =============================================================================
# Cleanup old backups
# =============================================================================
cleanup_old() {
  log_info "Cleaning backups older than ${RETENTION_DAYS} days..."

  case "$BACKUP_TARGET" in
    s3|b2|r2)
      if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would delete S3 objects older than ${RETENTION_DAYS} days"
      else
        local older_than
        older_than=$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d 2>/dev/null || date -v-"${RETENTION_DAYS}d" +%Y-%m-%d 2>/dev/null)
        AWS_PAGER="" aws s3 ls "${AWS_BUCKET:-homelab-backups}/" 2>/dev/null | while read -r date _ key; do
          if [[ "$date" < "$older_than" ]]; then
            log_info "  Deleting old backup: $key"
            AWS_PAGER="" aws s3 rm "${AWS_BUCKET:-homelab-backups}/${key}" --recursive 2>/dev/null || true
          fi
        done
      fi
      ;;
    sftp)
      log_warn "SFTP retention cleanup requires manual intervention or sftp command support"
      ;;
    local|*)
      if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would delete: $(find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" 2>/dev/null | tr '\n' ' ')"
      else
        find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true
      fi
      ;;
  esac
}

# =============================================================================
# Generate summary
# =============================================================================
generate_summary() {
  echo ""
  log_step "========== Backup Summary =========="
  log_info "Backup ID:   $BACKUP_ID"
  log_info "Target:      $BACKUP_TARGET"
  log_info "Type:       $TARGET_TYPE"
  log_info "Local path: $BACKUP_PATH"

  if [[ "$DRY_RUN" == true ]]; then
    log_warn "DRY-RUN mode — no actual data was written"
    return 0
  fi

  if [[ "$BACKUP_TARGET" != "local" ]]; then
    local remote
    remote=$(get_remote_path "${BACKUP_ID}.tar.gz")
    log_info "Remote:     $remote"
  fi

  if [[ -d "$BACKUP_PATH" ]]; then
    log_info "Size:"
    du -sh "$BACKUP_PATH"/* 2>/dev/null | sed 's/^/  /'
    log_info "Total:      $(du -sh "$BACKUP_PATH" | cut -f1)"
  fi
  log_step "===================================="
}

# =============================================================================
# MAIN
# =============================================================================
main() {
  if [[ "$LIST_MODE" == true ]]; then
    do_list
  elif [[ -n "$RESTORE_ID" ]]; then
    if [[ "$VERIFY_MODE" == true ]]; then
      do_verify
    else
      do_restore
    fi
  else
    do_backup
  fi
}

main
