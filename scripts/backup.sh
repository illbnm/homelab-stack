#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$BASE_DIR/config/.env"

[[ -f "$ENV_FILE" ]] && set -a && source "$ENV_FILE" && set +a

BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"
MEDIA_PATTERN="${MEDIA_PATTERN:-media}"

NTFY_URL="${NTFY_URL:-}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

log()  { echo "[backup] $*"; }
warn() { echo "[backup] WARNING: $*" >&2; }
die()  { echo "[backup] ERROR: $*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage:
  backup.sh --target <all|media> [options]

Options:
  --target all
  --target media
  --dry-run
  --restore <backup_id>
  --list
  --verify
  --help

Environment:
  BACKUP_TARGET=local|s3|b2|sftp
  BACKUP_DIR=/opt/homelab-backups
  NTFY_URL=https://ntfy.example/topic
EOF
}

notify() {
  local message="$1"
  [[ -z "$NTFY_URL" ]] && return 0

  curl -fsS \
    -H "Title: HomeLab Backup" \
    -d "$message" \
    "$NTFY_URL" >/dev/null 2>&1 || warn "ntfy notification failed"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

backup_configs() {
  log "Backing up configuration files..."

  tar czf "$BACKUP_PATH/configs.tar.gz" \
    -C "$BASE_DIR" \
    --exclude='stacks/*/data' \
    config/ stacks/ scripts/
}

backup_volumes() {
  log "Backing up Docker volumes..."

  require_cmd docker

  local volumes
  volumes="$(docker volume ls --format '{{.Name}}' || true)"

  while IFS= read -r vol; do
    [[ -z "$vol" ]] && continue

    if [[ "$MODE" == "media" ]] && [[ "$vol" != *"$MEDIA_PATTERN"* ]]; then
      continue
    fi

    log "Volume: $vol"

    docker run --rm \
      -v "${vol}:/data:ro" \
      -v "$BACKUP_PATH:/backup" \
      alpine:3.19 \
      tar czf "/backup/vol_${vol}.tar.gz" -C /data . \
      || warn "Failed to backup volume: $vol"
  done <<< "$volumes"
}

backup_databases() {
  require_cmd docker
  log "Backing up databases..."

  local container pass

  container="$(docker ps --format '{{.Names}}' | grep -E 'postgres|postgresql' | head -1 || true)"

  if [[ -n "$container" ]]; then
    pass="$(docker inspect "$container" \
      --format '{{range .Config.Env}}{{println .}}{{end}}' |
      grep '^POSTGRES_PASSWORD=' | cut -d= -f2- | head -1 || true)"

    docker exec "$container" \
      sh -c "PGPASSWORD='$pass' pg_dumpall -U postgres" \
      > "$BACKUP_PATH/postgresql_all.sql" \
      || warn "PostgreSQL backup failed"
  fi

  container="$(docker ps --format '{{.Names}}' | grep -E 'mariadb|mysql' | head -1 || true)"

  if [[ -n "$container" ]]; then
    pass="$(docker inspect "$container" \
      --format '{{range .Config.Env}}{{println .}}{{end}}' |
      grep '^MYSQL_ROOT_PASSWORD=' | cut -d= -f2- | head -1 || true)"

    docker exec "$container" \
      sh -c "mysqldump -u root -p'$pass' --all-databases" \
      > "$BACKUP_PATH/mysql_all.sql" \
      || warn "MySQL backup failed"
  fi
}

upload_backup() {
  case "$BACKUP_TARGET" in
    local)
      log "Local backup stored at $BACKUP_PATH"
      ;;

    s3|b2)
      require_cmd rclone
      [[ -n "${RCLONE_REMOTE:-}" ]] ||
        die "RCLONE_REMOTE is required for $BACKUP_TARGET"

      rclone copy "$BACKUP_PATH" \
        "${RCLONE_REMOTE}:$(basename "$BACKUP_PATH")"
      ;;

    sftp)
      require_cmd rsync
      [[ -n "${SFTP_DEST:-}" ]] ||
        die "SFTP_DEST is required"

      rsync -a "$BACKUP_PATH/" "$SFTP_DEST/$(basename "$BACKUP_PATH")/"
      ;;

    *)
      die "Unsupported BACKUP_TARGET: $BACKUP_TARGET"
      ;;
  esac
}

cleanup_old() {
  find "$BACKUP_DIR" \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    -mtime +"$RETENTION_DAYS" \
    -exec rm -rf {} +
}

do_backup() {
  mkdir -p "$BACKUP_PATH"

  log "Starting backup: $TIMESTAMP"
  log "Target: $MODE"
  log "Destination: $BACKUP_TARGET"

  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY-RUN: no files will be changed"
    docker volume ls --format '{{.Name}}' 2>/dev/null || true
    return 0
  fi

  backup_configs
  backup_volumes
  backup_databases

  sha256sum "$BACKUP_PATH"/* > "$BACKUP_PATH/SHA256SUMS" 2>/dev/null || true

  upload_backup
  cleanup_old

  notify "Backup completed successfully: $TIMESTAMP"

  log "Backup complete: $BACKUP_PATH"
}

list_backups() {
  mkdir -p "$BACKUP_DIR"
  find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' |
    sort -r
}

verify_backup() {
  local target="${BACKUP_ID:-}"

  [[ -n "$target" ]] || target="$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r | head -1)"
  [[ -n "$target" ]] || die "No backup found"

  local path="$BACKUP_DIR/$target"
  [[ -d "$path" ]] || die "Backup not found: $target"

  if [[ -f "$path/SHA256SUMS" ]]; then
    (cd "$path" && sha256sum -c SHA256SUMS)
  else
    tar -tzf "$path/configs.tar.gz" >/dev/null
    log "Backup archive verified: $target"
  fi
}

restore_backup() {
  local target="$BACKUP_ID"
  local path="$BACKUP_DIR/$target"

  [[ -d "$path" ]] || die "Backup not found: $target"

  log "Restoring backup: $target"

  if [[ -f "$path/configs.tar.gz" ]]; then
    tar xzf "$path/configs.tar.gz" -C "$BASE_DIR"
  fi

  log "Configuration restore completed."
  log "Docker volume archives are available in: $path"
}

MODE="all"
DRY_RUN="0"
BACKUP_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || die "--target requires a value"
      MODE="$2"
      shift 2
      ;;

    --dry-run)
      DRY_RUN="1"
      shift
      ;;

    --restore)
      [[ $# -ge 2 ]] || die "--restore requires a backup ID"
      BACKUP_ID="$2"
      shift 2
      ;;

    --list)
      list_backups
      exit 0
      ;;

    --verify)
      verify_backup
      exit 0
      ;;

    --help|-h)
      usage
      exit 0
      ;;

    *)
      die "Unknown option: $1"
      ;;
  esac
done

case "$MODE" in
  all|media) ;;
  *) die "Invalid target: $MODE" ;;
esac

if [[ -n "$BACKUP_ID" ]]; then
  restore_backup
else
  do_backup
fi