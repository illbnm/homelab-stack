#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup & Restore — 全量备份脚本
# 支持多种备份目标: local / s3 (MinIO) / b2 (Backblaze) / sftp / restic
# 用法:
#   ./backup.sh [OPTIONS]
#   ./backup.sh --target all|media|database  [--dest s3|b2|sftp|local]
#   ./backup.sh --dry-run --target all
#   ./backup.sh --restore --target database --backup-id <id>
#   ./backup.sh --list [--dest s3|b2|sftp|local]
#   ./backup.sh --verify [--backup-id <id>]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$BASE_DIR/config/.env"

[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# ── Defaults ──────────────────────────────────────────────────────────────────
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"
BACKUP_TARGET="${BACKUP_TARGET:-local}"   # local | s3 | b2 | sftp | restic
OPERATION="${OPERATION:-backup}"           # backup | restore | list | verify

# S3 / MinIO
S3_BUCKET="${S3_BUCKET:-homelab-backups}"
S3_ENDPOINT="${S3_ENDPOINT:-https://s3.${DOMAIN:-localhost}}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:-${MINIO_ROOT_USER:-minioadmin}}"
S3_SECRET_KEY="${S3_SECRET_KEY:-${MINIO_ROOT_PASSWORD:-changeme-minio}}"
S3_REGION="${S3_REGION:-us-east-1}"
S3_PREFIX="${S3_PREFIX:-backups}"

# Backblaze B2
B2_ACCOUNT_ID="${B2_ACCOUNT_ID:-}"
B2_ACCOUNT_KEY="${B2_ACCOUNT_KEY:-}"
B2_BUCKET="${B2_BUCKET:-homelab-backups}"
B2_PREFIX="${B2_PREFIX:-backups}"

# SFTP
SFTP_HOST="${SFTP_HOST:-}"
SFTP_PORT="${SFTP_PORT:-22}"
SFTP_USER="${SFTP_USER:-}"
SFTP_KEY="${SFTP_KEY:-}"          # path to private key
SFTP_REMOTE_PATH="${SFTP_REMOTE_PATH:-/backups}"

# Restic REST Server
RESTIC_REST_URL="${RESTIC_REST_URL:-http://localhost:8080}"
RESTIC_REST_PASSWORD="${RESTIC_REST_PASSWORD:-changeme}"

# Notification
NTFY_URL="${NTFY_URL:-http://ntfy.${DOMAIN:-localhost}}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab-backups}"
NTFY_AUTH="${NTFY_AUTH:-}"

# ── CLI Args ───────────────────────────────────────────────────────────────────
TARGET_TYPE="all"    # all | media | database
DRY_RUN=false
BACKUP_ID=""
DEST_BACKEND=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)    TARGET_TYPE="$2"; shift 2 ;;
    --dest)      DEST_BACKEND="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --restore)   OPERATION="restore"; shift ;;
    --list)      OPERATION="list"; shift ;;
    --verify)    OPERATION="verify"; shift ;;
    --backup-id) BACKUP_ID="$2"; shift 2 ;;
    --help)
      echo "Usage: $0 [--target all|media|database] [--dest s3|b2|sftp|local|restic]"
      echo "       [--dry-run] [--restore] [--list] [--verify] [--backup-id <id>]"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

DEST_BACKEND="${DEST_BACKEND:-$BACKUP_TARGET}"

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error() { echo -e "${RED}[backup]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[backup]${NC} ▶ $*"; }

# ── Notification ───────────────────────────────────────────────────────────────
notify() {
  local level="$1"   # success | warning | error
  local message="$2"
  local tag=""
  case "$level" in
    success) tag="✅" ;;
    warning) tag="⚠️" ;;
    error)   tag="🚨" ;;
  esac

  local body="[Homelab Backup] $tag $message"
  if [[ -n "$NTFY_AUTH" ]]; then
    curl -s -u "$NTFY_AUTH" \
      -H "Tags: $level" \
      -H "Title: Homelab Backup" \
      -d "$body" \
      "${NTFY_URL}/$NTFY_TOPIC" > /dev/null 2>&1 || true
  else
    curl -s \
      -H "Tags: $level" \
      -H "Title: Homelab Backup" \
      -d "$body" \
      "${NTFY_URL}/$NTFY_TOPIC" > /dev/null 2>&1 || true
  fi
}

notify_success() { notify "success" "$1"; }
notify_warn()    { notify "warning" "$1"; }
notify_error()   { notify "error" "$1"; }

# ── Dependency checks ──────────────────────────────────────────────────────────
check_deps() {
  local missing=()
  command -v docker >/dev/null 2>&1 || missing+=(docker)
  command -v rclone >/dev/null 2>&1 || missing+=(rclone)
  command -v restic >/dev/null 2>&1 || missing+=(restic)
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_warn "Missing tools: ${missing[*]} — install for full functionality"
  fi
}
check_deps

# ── Backend helpers ───────────────────────────────────────────────────────────

# Upload a local file/folder to the chosen backend
upload_to_backend() {
  local src="$1"
  local dest_name="$2"   # backup set identifier / folder name

  case "$DEST_BACKEND" in
    local)
      local local_dest="$BACKUP_DIR/$dest_name"
      mkdir -p "$local_dest"
      [[ "$src" != "$local_dest" ]] && cp -r "$src" "$local_dest/"
      log_info "Stored locally: $local_dest"
      ;;

    s3)
      check_s3_deps
      export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
      export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
      local s3_path="s3://${S3_BUCKET}/${S3_PREFIX}/${dest_name}/"
      log_info "Uploading to S3: $s3_path"
      [[ "$DRY_RUN" == true ]] && { log_info "[dry-run] Would upload $src to $s3_path"; return 0; }
      rclone copy "$src" "$s3_path" \
        --s3-endpoint "$S3_ENDPOINT" \
        --s3-region "$S3_REGION" \
        --s3-access-key-id "$S3_ACCESS_KEY" \
        --s3-secret-access-key "$S3_SECRET_KEY" \
        --copy-links \
        --progress 2>&1 || log_warn "S3 upload failed — check credentials"
      ;;

    b2)
      check_b2_deps
      local b2_path="b2://${B2_BUCKET}/${B2_PREFIX}/${dest_name}/"
      log_info "Uploading to B2: $b2_path"
      [[ "$DRY_RUN" == true ]] && { log_info "[dry-run] Would upload $src to $b2_path"; return 0; }
      rclone copy "$src" "$b2_path" \
        --b2-account "$B2_ACCOUNT_ID" \
        --b2-key "$B2_ACCOUNT_KEY" \
        --progress 2>&1 || log_warn "B2 upload failed — check credentials"
      ;;

    sftp)
      check_sftp_deps
      local sftp_dest="${SFTP_USER}@${SFTP_HOST}:${SFTP_REMOTE_PATH}/${dest_name}/"
      log_info "Uploading to SFTP: $sftp_dest"
      [[ "$DRY_RUN" == true ]] && { log_info "[dry-run] Would upload $src to $sftp_dest"; return 0; }
      rclone copy "$src" "$sftp_dest" \
        --sftp-port "$SFTP_PORT" \
        --sftp-key-file "$SFTP_KEY" \
        --progress 2>&1 || log_warn "SFTP upload failed — check credentials"
      ;;

    restic)
      check_restic_deps
      export RESTIC_PASSWORD="$RESTIC_REST_PASSWORD"
      log_info "Uploading to Restic: $RESTIC_REST_URL"
      [[ "$DRY_RUN" == true ]] && { log_info "[dry-run] Would backup $src via restic"; return 0; }
      # Use rclone as backend bridge for rest-server
      restic backup "$src" \
        --repo "rest:http://${RESTIC_REST_URL}/" \
        --password-env-file <(echo "RESTIC_PASSWORD=$RESTIC_REST_PASSWORD") \
        --tag "$dest_name" \
        --verbose 2>&1 || log_warn "Restic backup failed"
      ;;

    *)
      log_error "Unknown BACKUP_TARGET/DEST: $DEST_BACKEND"
      return 1
      ;;
  esac
}

check_s3_deps()  { command -v rclone >/dev/null 2>&1 || { log_error "rclone required for S3"; exit 1; }; }
check_b2_deps()  { command -v rclone >/dev/null 2>&1 || { log_error "rclone required for B2"; exit 1; }; }
check_sftp_deps(){ command -v rclone >/dev/null 2>&1 || { log_error "rclone required for SFTP"; exit 1; }; }
check_restic_deps(){ command -v restic >/dev/null 2>&1 || { log_error "restic required for restic backend"; exit 1; }; }

# ── Backup: configs ────────────────────────────────────────────────────────────
backup_configs() {
  log_step "Backing up configs & scripts..."
  tar czf "$BACKUP_PATH/configs.tar.gz" \
    -C "$BASE_DIR" \
    --exclude='stacks/*/data' \
    --exclude='.git' \
    --exclude='*.log' \
    config/ stacks/ scripts/ homelab.md README.md 2>/dev/null || true
  echo "$BACKUP_PATH/configs.tar.gz"
}

# ── Backup: Docker volumes ─────────────────────────────────────────────────────
backup_volumes() {
  log_step "Backing up Docker volumes..."
  mkdir -p "$BACKUP_PATH/volumes"
  local volumes
  volumes=$(docker volume ls --format '{{.Name}}' | grep -v '^[a-f0-9]\{64\}$' || true)
  local count=0
  while IFS= read -r vol; do
    [[ -z "$vol" ]] && continue
    log_info "  Volume: $vol"
    if [[ "$DRY_RUN" == true ]]; then
      log_info "  [dry-run] Would tar $vol"
    else
      docker run --rm \
        -v "${vol}:/data:ro" \
        -v "$BACKUP_PATH/volumes:/backup" \
        alpine:3.19 \
        tar czf "/backup/vol_${vol}.tar.gz" -C /data . 2>/dev/null || \
        log_warn "  Failed: $vol"
    fi
    ((count++)) || true
  done <<< "$volumes"
  echo "$count volumes"
}

# ── Backup: databases ─────────────────────────────────────────────────────────
backup_databases() {
  log_step "Backing up databases..."
  mkdir -p "$BACKUP_PATH/databases"

  # PostgreSQL
  if docker ps --format '{{.Names}}' | grep -qE 'postgres|postgresql'; then
    local pg_container
    pg_container=$(docker ps --format '{{.Names}}' | grep -E 'postgres|postgresql' | head -1)
    local pg_pass
    pg_pass=$(docker inspect "$pg_container" --format '{{range .Config.Env}}{{println .}}{{end}}' \
      | grep POSTGRES_PASSWORD | cut -d= -f2 | head -1)
    if [[ -n "$pg_pass" ]]; then
      log_info "  PostgreSQL: $pg_container"
      [[ "$DRY_RUN" != true ]] && \
        docker exec "$pg_container" \
          sh -c "PGPASSWORD='$pg_pass' pg_dumpall -U postgres" \
          > "$BACKUP_PATH/databases/postgresql_all.sql" 2>/dev/null || \
          log_warn "  PostgreSQL backup failed"
    fi
  fi

  # MariaDB/MySQL
  if docker ps --format '{{.Names}}' | grep -qE 'mariadb|mysql'; then
    local mysql_container
    mysql_container=$(docker ps --format '{{.Names}}' | grep -E 'mariadb|mysql' | head -1)
    local mysql_pass
    mysql_pass=$(docker inspect "$mysql_container" --format '{{range .Config.Env}}{{println .}}{{end}}' \
      | grep MYSQL_ROOT_PASSWORD | cut -d= -f2 | head -1)
    if [[ -n "$mysql_pass" ]]; then
      log_info "  MariaDB: $mysql_container"
      [[ "$DRY_RUN" != true ]] && \
        docker exec "$mysql_container" \
          sh -c "mysqldump -u root -p'$mysql_pass' --all-databases" \
          > "$BACKUP_PATH/databases/mysql_all.sql" 2>/dev/null || \
          log_warn "  MariaDB backup failed"
    fi
  fi

  # Redis
  if docker ps --format '{{.Names}}' | grep -q 'redis'; then
    local redis_container
    redis_container=$(docker ps --format '{{.Names}}' | grep 'redis' | head -1)
    log_info "  Redis: $redis_container"
    [[ "$DRY_RUN" != true ]] && \
      docker exec "$redis_container" redis-cli \
        -a "${REDIS_PASSWORD:-}" --no-auth-warning SAVE 2>/dev/null && \
      docker cp "$redis_container:/data/dump.rdb" "$BACKUP_PATH/databases/redis_dump.rdb" 2>/dev/null || \
      log_warn "  Redis backup failed"
  fi

  echo "$BACKUP_PATH/databases/"
}

# ── Backup: media files ────────────────────────────────────────────────────────
backup_media() {
  log_step "Backing up media files..."
  local media_root="${MEDIA_ROOT:-/opt/homelab/media}"
  if [[ -d "$media_root" ]]; then
    mkdir -p "$BACKUP_PATH/media"
    log_info "  Media root: $media_root"
    [[ "$DRY_RUN" != true ]] && \
      rsync -av --quiet "$media_root/" "$BACKUP_PATH/media/" 2>/dev/null || \
      log_warn "  Media rsync failed — trying tar" && \
      tar czf "$BACKUP_PATH/media.tar.gz" -C "$(dirname "$media_root")" "$(basename "$media_root")" 2>/dev/null || true
  else
    log_warn "  Media root not found: $media_root — skipping"
  fi
  echo "$BACKUP_PATH/media/"
}

# ── Cleanup old backups ────────────────────────────────────────────────────────
cleanup_old() {
  log_step "Cleaning backups older than ${RETENTION_DAYS} days..."
  # Local cleanup
  find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true

  # Backend-specific retention (using rclone backend listing)
  case "$DEST_BACKEND" in
    s3)
      export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
      export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
      rclone delete "s3://${S3_BUCKET}/${S3_PREFIX}/" \
        --s3-endpoint "$S3_ENDPOINT" \
        --min-age "${RETENTION_DAYS}d" \
        --drive-use-trash=false \
        2>/dev/null || true
      ;;
    b2)
      rclone delete "b2://${B2_BUCKET}/${B2_PREFIX}/" \
        --b2-account "$B2_ACCOUNT_ID" \
        --b2-key "$B2_ACCOUNT_KEY" \
        --min-age "${RETENTION_DAYS}d" \
        2>/dev/null || true
      ;;
    sftp)
      rclone delete "${SFTP_USER}@${SFTP_HOST}:${SFTP_REMOTE_PATH}/" \
        --sftp-port "$SFTP_PORT" \
        --sftp-key-file "$SFTP_KEY" \
        --min-age "${RETENTION_DAYS}d" \
        2>/dev/null || true
      ;;
    restic)
      export RESTIC_PASSWORD="$RESTIC_REST_PASSWORD"
      restic forget \
        --repo "rest:http://${RESTIC_REST_URL}/" \
        --password-env-file <(echo "RESTIC_PASSWORD=$RESTIC_REST_PASSWORD") \
        --keep-daily 7 --keep-weekly 4 --keep-monthly 6 \
        2>/dev/null || true
      ;;
  esac
}

# ── Backup summary ────────────────────────────────────────────────────────────
generate_summary() {
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[dry-run] Backup complete (no data written)"
    return
  fi
  local total_size
  total_size=$(du -sh "$BACKUP_PATH" 2>/dev/null | cut -f1 || echo "unknown")
  log_info "Backup set: $BACKUP_PATH ($total_size)"
  ls -lh "$BACKUP_PATH/" 2>/dev/null || true
  echo ""
  log_info "Summary:"
  echo "  Target type : $TARGET_TYPE"
  echo "  Dest backend: $DEST_BACKEND"
  echo "  Path        : $BACKUP_PATH"
  echo "  Size        : $total_size"
  echo "  Timestamp   : $TIMESTAMP"
}

# ── Upload staging folder to backend ─────────────────────────────────────────
upload_staging() {
  if [[ "$DEST_BACKEND" == "local" ]]; then
    return 0  # already local
  fi
  log_step "Uploading backup set to $DEST_BACKEND..."
  upload_to_backend "$BACKUP_PATH" "$TIMESTAMP"
}

# ── Main backup ───────────────────────────────────────────────────────────────
do_backup() {
  log_info "=== Homelab Backup — $(date) ==="
  log_info "Target : $TARGET_TYPE"
  log_info "Dest  : $DEST_BACKEND"
  log_info "DRY   : $DRY_RUN"
  echo ""

  mkdir -p "$BACKUP_PATH"

  if [[ "$TARGET_TYPE" == "all" ]]; then
    backup_configs
    backup_volumes
    backup_databases
    backup_media
  elif [[ "$TARGET_TYPE" == "media" ]]; then
    backup_media
  elif [[ "$TARGET_TYPE" == "database" ]]; then
    backup_databases
  else
    log_error "Unknown --target: $TARGET_TYPE (use: all|media|database)"
    exit 1
  fi

  upload_staging
  cleanup_old
  generate_summary

  notify_success "Backup complete — $TARGET_TYPE → $DEST_BACKEND — $TIMESTAMP"
}

# ── List backups ──────────────────────────────────────────────────────────────
do_list() {
  log_info "Available backups on: $DEST_BACKEND"
  echo ""

  case "$DEST_BACKEND" in
    local)
      if [[ -d "$BACKUP_DIR" ]]; then
        find "$BACKUP_DIR" -maxdepth 2 -type d | sort | while read -r d; do
          local sz
          sz=$(du -sh "$d" 2>/dev/null | cut -f1 || echo "?")
          echo "  $d  ($sz)"
        done
      fi
      ;;
    s3)
      export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
      export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
      rclone lsl "s3://${S3_BUCKET}/${S3_PREFIX}/" \
        --s3-endpoint "$S3_ENDPOINT" \
        --s3-region "$S3_REGION" 2>/dev/null | head -50 || log_warn "Failed to list S3"
      ;;
    b2)
      rclone lsl "b2://${B2_BUCKET}/${B2_PREFIX}/" \
        --b2-account "$B2_ACCOUNT_ID" \
        --b2-key "$B2_ACCOUNT_KEY" 2>/dev/null | head -50 || log_warn "Failed to list B2"
      ;;
    sftp)
      rclone lsl "${SFTP_USER}@${SFTP_HOST}:${SFTP_REMOTE_PATH}/" \
        --sftp-port "$SFTP_PORT" \
        --sftp-key-file "$SFTP_KEY" 2>/dev/null | head -50 || log_warn "Failed to list SFTP"
      ;;
    restic)
      export RESTIC_PASSWORD="$RESTIC_REST_PASSWORD"
      restic snapshots \
        --repo "rest:http://${RESTIC_REST_URL}/" \
        --password-env-file <(echo "RESTIC_PASSWORD=$RESTIC_REST_PASSWORD") \
        2>/dev/null || log_warn "Failed to list restic snapshots"
      ;;
  esac
}

# ── Verify backup ─────────────────────────────────────────────────────────────
do_verify() {
  log_info "Verifying backup: ${BACKUP_ID:-latest} on $DEST_BACKEND"
  echo ""

  local snapshot_path=""
  case "$DEST_BACKEND" in
    restic)
      check_restic_deps
      export RESTIC_PASSWORD="$RESTIC_REST_PASSWORD"
      if [[ -n "$BACKUP_ID" ]]; then
        restic check \
          --repo "rest:http://${RESTIC_REST_URL}/" \
          --password-env-file <(echo "RESTIC_PASSWORD=$RESTIC_REST_PASSWORD") \
          2>&1 || { notify_error "Backup verify FAILED: $BACKUP_ID"; exit 1; }
      else
        restic check \
          --repo "rest:http://${RESTIC_REST_URL}/" \
          --password-env-file <(echo "RESTIC_PASSWORD=$RESTIC_REST_PASSWORD") \
          2>&1 || { notify_error "Backup verify FAILED"; exit 1; }
      fi
      notify_success "Backup verify OK: $BACKUP_ID"
      ;;

    local)
      snapshot_path="$BACKUP_DIR/${BACKUP_ID:-$TIMESTAMP}"
      if [[ ! -d "$snapshot_path" ]]; then
        log_error "Backup not found: $snapshot_path"
        notify_error "Backup verify failed: not found $snapshot_path"
        exit 1
      fi
      log_info "Checking archive integrity..."
      # Verify tar files
      find "$snapshot_path" -name "*.tar.gz" -exec sh -c '
        for f; do
          if tar tzf "$f" > /dev/null 2>&1; then
            echo "  ✅  $(basename $f)"
          else
            echo "  ❌  $(basename $f) — CORRUPT"
            exit 1
          fi
        done
      ' _ {} + || { notify_error "Backup verify FAILED: corrupt archive"; exit 1; }
      # Verify SQL files
      find "$snapshot_path" -name "*.sql" -exec sh -c '
        for f; do
          if head -c 10 "$f" | grep -qE "^PGDMP|^-- MySQL"; then
            echo "  ✅  $(basename $f)"
          else
            echo "  ❌  $(basename $f) — CORRUPT"
            exit 1
          fi
        done
      ' _ {} + || { notify_error "Backup verify FAILED: corrupt SQL"; exit 1; }
      notify_success "Backup verify OK: $snapshot_path"
      ;;
    *)
      log_warn "Verify not fully implemented for $DEST_BACKEND — use restic or local"
      ;;
  esac
}

# ── Restore ────────────────────────────────────────────────────────────────────
do_restore() {
  local restore_id="${BACKUP_ID:-$TIMESTAMP}"
  log_info "Restoring from backup: $restore_id (backend: $DEST_BACKEND)"
  log_warn "Restore is interactive — ensure target services are stopped first"
  echo ""

  # Download backup set to temp location if not local
  local staging="$BACKUP_DIR/.restore_tmp"
  mkdir -p "$staging"

  if [[ "$DEST_BACKEND" != "local" ]]; then
    log_step "Downloading backup from $DEST_BACKEND..."
    case "$DEST_BACKEND" in
      s3)
        export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
        export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
        rclone copy "s3://${S3_BUCKET}/${S3_PREFIX}/${restore_id}/" "$staging/" \
          --s3-endpoint "$S3_ENDPOINT" \
          --s3-region "$S3_REGION" || { log_error "Download failed"; exit 1; }
        ;;
      b2)
        rclone copy "b2://${B2_BUCKET}/${B2_PREFIX}/${restore_id}/" "$staging/" \
          --b2-account "$B2_ACCOUNT_ID" \
          --b2-key "$B2_ACCOUNT_KEY" || { log_error "Download failed"; exit 1; }
        ;;
      sftp)
        rclone copy "${SFTP_USER}@${SFTP_HOST}:${SFTP_REMOTE_PATH}/${restore_id}/" "$staging/" \
          --sftp-port "$SFTP_PORT" \
          --sftp-key-file "$SFTP_KEY" || { log_error "Download failed"; exit 1; }
        ;;
      restic)
        check_restic_deps
        export RESTIC_PASSWORD="$RESTIC_REST_PASSWORD"
        restic restore latest \
          --repo "rest:http://${RESTIC_REST_URL}/" \
          --password-env-file <(echo "RESTIC_PASSWORD=$RESTIC_REST_PASSWORD") \
          --target /tmp/restic-restore || { log_error "Restic restore failed"; exit 1; }
        staging="/tmp/restic-restore"
        ;;
    esac
  else
    staging="$BACKUP_DIR/$restore_id"
    [[ ! -d "$staging" ]] && { log_error "Backup not found: $staging"; exit 1; }
  fi

  log_info "Staging path: $staging"
  ls -lh "$staging/"

  # Restore based on target
  if [[ "$TARGET_TYPE" == "database" ]]; then
    log_step "Restoring databases..."
    if [[ -f "$staging/databases/postgresql_all.sql" ]]; then
      log_info "  Restoring PostgreSQL..."
      docker exec homelab-postgres psql -U postgres -f /dev/stdin \
        < "$staging/databases/postgresql_all.sql" 2>/dev/null || \
        log_warn "  PostgreSQL restore — may need manual attention"
    fi
    if [[ -f "$staging/databases/mysql_all.sql" ]]; then
      log_info "  Restoring MariaDB..."
      docker exec homelab-mariadb mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" \
        < "$staging/databases/mysql_all.sql" 2>/dev/null || \
        log_warn "  MariaDB restore — may need manual attention"
    fi
  elif [[ "$TARGET_TYPE" == "media" ]]; then
    log_step "Restoring media files..."
    rsync -av "$staging/media/" "${MEDIA_ROOT:-/opt/homelab/media}/" 2>/dev/null || \
      log_warn "Media restore may be incomplete"
  elif [[ "$TARGET_TYPE" == "all" ]]; then
    log_step "Full restore (configs + databases + volumes)..."
    # Configs
    tar xzf "$staging/configs.tar.gz" -C "$BASE_DIR" 2>/dev/null || true
    # Databases
    [[ -f "$staging/databases/postgresql_all.sql" ]] && \
      docker exec homelab-postgres psql -U postgres < "$staging/databases/postgresql_all.sql" 2>/dev/null || true
    # Volumes
    for vol_tar in "$staging/volumes"/vol_*.tar.gz; do
      [[ -f "$vol_tar" ]] || continue
      local vol_name
      vol_name=$(basename "$vol_tar" .tar.gz | sed 's/^vol_//')
      log_info "  Restoring volume: $vol_name"
      docker run --rm \
        -v "${vol_name}:/data" \
        -v "$staging/volumes:/backup:ro" \
        alpine:3.19 \
        sh -c "rm -rf /data/* && tar xzf '/backup/$(basename $vol_tar)' -C /data" 2>/dev/null || \
        log_warn "  Volume restore failed: $vol_name"
    done
  fi

  log_info "Restore complete: $restore_id"
  notify_success "Restore complete: $restore_id"

  # Cleanup staging
  [[ "$DEST_BACKEND" != "local" ]] && rm -rf "$staging"
}

# ── Trap for errors ───────────────────────────────────────────────────────────
trap 'notify_error "Backup FAILED on line $LINENO" || true' ERR

# ── Dispatch ───────────────────────────────────────────────────────────────────
case "$OPERATION" in
  backup)  do_backup ;;
  restore) do_restore ;;
  list)    do_list ;;
  verify)  do_verify ;;
  *)       log_error "Unknown operation: $OPERATION"; exit 1 ;;
esac
