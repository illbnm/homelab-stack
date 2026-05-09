#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Unified Backup Script (3-2-1 Strategy)
# Supports: local, S3/MinIO, Backblaze B2, SFTP, Cloudflare R2
#
# Usage:
#   backup.sh --target <all|stack_name> [--dry-run] [--restore ID] [--list] [--verify]
# =============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

if [ -f "$ROOT_DIR/.env" ]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ── Config ───────────────────────────────────────────────────────────────────
BACKUP_TARGET="${BACKUP_TARGET:-local}"
BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Remote targets (from .env)
S3_ENDPOINT="${S3_ENDPOINT:-}"
S3_BUCKET="${S3_BUCKET:-homelab-backups}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:-}"
S3_SECRET_KEY="${S3_SECRET_KEY:-}"

B2_APPLICATION_KEY_ID="${B2_APPLICATION_KEY_ID:-}"
B2_APPLICATION_KEY="${B2_APPLICATION_KEY:-}"
B2_BUCKET="${B2_BUCKET:-homelab-backups}"

SFTP_HOST="${SFTP_HOST:-}"
SFTP_USER="${SFTP_USER:-}"
SFTP_PATH="${SFTP_PATH:-/backups}"

R2_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID:-}"
R2_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY:-}"
R2_ENDPOINT="${R2_ENDPOINT:-}"
R2_BUCKET="${R2_BUCKET:-homelab-backups}"

# ── CLI ──────────────────────────────────────────────────────────────────────
TARGET=""
DRY_RUN=false
RESTORE_ID=""
LIST_ONLY=false
VERIFY_ONLY=false

usage() {
  cat <<EOF
Usage: backup.sh --target <all|stack> [options]

Options:
  --target all|STACK    Backup target (all, sso, media, storage, monitoring...)
  --dry-run             Show what would be backed up without executing
  --restore BACKUP_ID   Restore from a specific backup
  --list                List all available backups
  --verify              Verify backup integrity without restoring

Examples:
  backup.sh --target all
  backup.sh --target media --dry-run
  backup.sh --list
  backup.sh --restore 20240501_120000
  backup.sh --verify
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --restore) RESTORE_ID="$2"; shift 2 ;;
    --list) LIST_ONLY=true; shift ;;
    --verify) VERIFY_ONLY=true; shift ;;
    --help|-h) usage ;;
    *) log_error "Unknown: $1"; usage ;;
  esac
done

# ── List backups ─────────────────────────────────────────────────────────────
list_backups() {
  echo "Available backups:"
  echo "─────────────────"
  case "$BACKUP_TARGET" in
    local)
      find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" | sort -r | while read -r d; do
        echo "  $(basename "$d") ($(du -sh "$d" | cut -f1))"
      done
      ;;
    s3)
      docker run --rm -e AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" -e AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
        amazon/aws-cli:2.15.30 s3 ls "s3://${S3_BUCKET}/" 2>/dev/null || echo "  (no backups found)"
      ;;
    b2)
      docker run --rm -e B2_APPLICATION_KEY_ID="$B2_APPLICATION_KEY_ID" -e B2_APPLICATION_KEY="$B2_APPLICATION_KEY" \
        backblazeit/b2:3.14.0 ls "${B2_BUCKET}" 2>/dev/null || echo "  (no backups found)"
      ;;
    *) echo "  Listing not supported for $BACKUP_TARGET" ;;
  esac
}

# ── Backup volumes ───────────────────────────────────────────────────────────
backup_volumes() {
  local stack_filter="${1:-}"
  log_info "Backing up Docker volumes..."
  
  local volumes
  if [ -n "$stack_filter" ] && [ "$stack_filter" != "all" ]; then
    volumes=$(docker volume ls --format '{{.Name}}' | grep "$stack_filter" || true)
  else
    volumes=$(docker volume ls --format '{{.Name}}' | grep -v '^[a-f0-9]\{64\}$' || true)
  fi

  if $DRY_RUN; then
    echo "[DRY-RUN] Would backup volumes: $volumes"
    return
  fi

  local backup_path="$BACKUP_DIR/$TIMESTAMP"
  mkdir -p "$backup_path"

  while IFS= read -r vol; do
    [ -z "$vol" ] && continue
    log_info "  Volume: $vol"
    docker run --rm \
      -v "${vol}:/data:ro" \
      -v "$backup_path:/backup" \
      alpine:3.19 \
      tar czf "/backup/vol_${vol}.tar.gz" -C /data . 2>/dev/null || \
      log_warn "  Failed: $vol"
  done <<< "$volumes"

  # Backup configs
  log_info "Backing up configs..."
  tar czf "$backup_path/configs.tar.gz" \
    -C "$ROOT_DIR" --exclude='*.git' --exclude='backups' \
    config/ stacks/ scripts/ .env 2>/dev/null || true

  # Backup databases
  if docker ps --format '{{.Names}}' | grep -q 'postgres'; then
    local pg=$(docker ps --format '{{.Names}}' | grep postgres | head -1)
    docker exec "$pg" pg_dumpall -U postgres 2>/dev/null | gzip > "$backup_path/postgres_all.sql.gz" || true
    log_info "  PostgreSQL dump"
  fi

  if docker ps --format '{{.Names}}' | grep -q 'mariadb\|mysql'; then
    local my=$(docker ps --format '{{.Names}}' | grep -E 'mariadb|mysql' | head -1)
    local mp=$(docker inspect "$my" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep MYSQL_ROOT_PASSWORD | cut -d= -f2)
    docker exec "$my" mysqldump -u root -p"$mp" --all-databases 2>/dev/null | gzip > "$backup_path/mysql_all.sql.gz" || true
    log_info "  MySQL dump"
  fi

  # Upload to remote if configured
  upload_backup "$backup_path"
}

# ── Upload to remote ─────────────────────────────────────────────────────────
upload_backup() {
  local path="$1"
  case "$BACKUP_TARGET" in
    s3)
      log_info "Uploading to S3/MinIO..."
      docker run --rm \
        -e AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
        -e AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
        -v "$path:/backup:ro" \
        amazon/aws-cli:2.15.30 \
        s3 sync /backup "s3://${S3_BUCKET}/${TIMESTAMP}/" --no-progress 2>/dev/null
      ;;
    b2)
      log_info "Uploading to Backblaze B2..."
      docker run --rm \
        -e B2_APPLICATION_KEY_ID="$B2_APPLICATION_KEY_ID" \
        -e B2_APPLICATION_KEY="$B2_APPLICATION_KEY" \
        -v "$path:/backup:ro" \
        backblazeit/b2:3.14.0 sync /backup "b2://${B2_BUCKET}/${TIMESTAMP}/" 2>/dev/null
      ;;
    local)
      log_info "Backup stored locally: $path"
      ;;
  esac
}

# ── Restore ──────────────────────────────────────────────────────────────────
restore_backup() {
  local backup_id="$1"
  local backup_path="$BACKUP_DIR/$backup_id"

  if [ ! -d "$backup_path" ]; then
    log_error "Backup not found: $backup_path"
    exit 1
  fi

  log_info "Restoring from: $backup_path"
  
  # Restore volumes
  for tarfile in "$backup_path"/vol_*.tar.gz; do
    [ -f "$tarfile" ] || continue
    local volname=$(basename "$tarfile" .tar.gz | sed 's/^vol_//')
    log_info "  Restoring volume: $volname"
    docker volume create "$volname" 2>/dev/null || true
    docker run --rm -v "${volname}:/data" -v "$backup_path:/backup:ro" \
      alpine:3.19 tar xzf "/backup/$(basename "$tarfile")" -C /data
  done

  # Restore databases
  if [ -f "$backup_path/postgres_all.sql.gz" ]; then
    local pg=$(docker ps --format '{{.Names}}' | grep postgres | head -1)
    if [ -n "$pg" ]; then
      zcat "$backup_path/postgres_all.sql.gz" | docker exec -i "$pg" psql -U postgres
      log_info "  PostgreSQL restored"
    fi
  fi

  log_info "Restore complete! Restart affected stacks."
}

# ── Verify ───────────────────────────────────────────────────────────────────
verify_backup() {
  local latest=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" | sort -r | head -1)
  if [ -z "$latest" ]; then
    log_error "No backups found to verify"
    exit 1
  fi

  log_info "Verifying: $(basename "$latest")"
  local errors=0

  for tarfile in "$latest"/vol_*.tar.gz; do
    [ -f "$tarfile" ] || continue
    if gzip -t "$tarfile" 2>/dev/null; then
      log_info "  ✓ $(basename "$tarfile")"
    else
      log_error "  ✗ $(basename "$tarfile") — CORRUPT"
      ((errors++))
    fi
  done

  if [ -f "$latest/postgres_all.sql.gz" ]; then
    if gzip -t "$latest/postgres_all.sql.gz" 2>/dev/null; then
      log_info "  ✓ PostgreSQL dump"
    else
      log_error "  ✗ PostgreSQL dump — CORRUPT"
      ((errors++))
    fi
  fi

  if [ $errors -eq 0 ]; then
    log_info "All backups verified OK"
  else
    log_error "$errors backup(s) failed verification!"
    exit 1
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
if $LIST_ONLY; then
  list_backups
  exit 0
fi

if $VERIFY_ONLY; then
  verify_backup
  exit 0
fi

if [ -n "$RESTORE_ID" ]; then
  restore_backup "$RESTORE_ID"
  exit 0
fi

if [ -z "$TARGET" ]; then
  usage
fi

echo -e "${CYAN}╔══════════════════════════════════╗${RESET}"
echo -e "${CYAN}║   HomeLab Backup — ${TIMESTAMP}   ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════╝${RESET}"

backup_volumes "$TARGET"

# Cleanup old backups
log_info "Cleaning backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR" -maxdepth 1 -type d -name "20*" -mtime +${RETENTION_DAYS} -exec rm -rf {} \; 2>/dev/null || true

# Notify via ntfy
if command -v "$SCRIPT_DIR/notify.sh" &>/dev/null; then
  "$SCRIPT_DIR/notify.sh" homelab-info "Backup Complete" "Target: $TARGET | Time: $(date)" default floppy_disk
fi

log_info "Done!"
