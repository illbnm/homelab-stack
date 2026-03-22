#!/usr/bin/env bash
# =============================================================================
# backup.sh — HomeLab Stack unified backup script (3-2-1 strategy)
# Usage: backup.sh --target <stack|all> [--dry-run] [--restore <id>] [--list] [--verify]
# =============================================================================
set -euo pipefail

# Load .env if present
[[ -f .env ]] && { set -a; source .env; set +a; }

BACKUP_DIR="${BACKUP_DIR:-/backups}"
RETAIN_DAYS="${RETAIN_DAYS:-7}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"  # local|s3|b2|sftp
NTFY_URL="${NTFY_URL:-}"
TARGET="all"
DRY_RUN=false
DATE=$(date +%Y%m%d_%H%M%S)

usage() {
  echo "Usage: $0 [options]"
  echo "  --target <stack|all>   Stack to backup (default: all)"
  echo "  --dry-run              Show what would be backed up"
  echo "  --restore <backup_id>  Restore from backup"
  echo "  --list                 List all backups"
  echo "  --verify               Verify backup integrity"
  exit 0
}

notify() {
  local msg=$1
  [[ -n "$NTFY_URL" ]] && curl -s -d "$msg" "$NTFY_URL/homelab-backup" || true
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --target) TARGET=$2; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --restore) RESTORE_ID=$2; shift 2 ;;
    --list) LIST=true; shift ;;
    --verify) VERIFY=true; shift ;;
    --help) usage ;;
    *) echo "Unknown: $1"; usage ;;
  esac
done

mkdir -p "$BACKUP_DIR"

backup_volumes() {
  local stack=$1
  local dest="$BACKUP_DIR/${stack}_${DATE}.tar.gz"

  echo "Backing up: $stack"
  if $DRY_RUN; then
    echo "  [DRY RUN] Would create: $dest"
    return
  fi

  # Get all volumes for this stack from docker compose
  local volumes
  volumes=$(docker compose -f "stacks/${stack}/docker-compose.yml" config --volumes 2>/dev/null || echo "")

  if [[ -z "$volumes" ]]; then
    echo "  No volumes found for $stack"
    return
  fi

  # Backup each volume
  local vol_args=""
  while IFS= read -r vol; do
    vol_args="$vol_args -v ${stack}_${vol}:/backup/${vol}:ro"
  done <<< "$volumes"

  docker run --rm $vol_args -v "$BACKUP_DIR":/dest alpine \
    tar czf "/dest/${stack}_${DATE}.tar.gz" /backup/ 2>/dev/null

  echo "  ✅ $dest ($(du -sh "$dest" | cut -f1))"
}

list_backups() {
  echo "=== Backups in $BACKUP_DIR ==="
  find "$BACKUP_DIR" -name "*.tar.gz" -printf "%T@ %p\n" 2>/dev/null | \
    sort -rn | awk '{print $2}' | head -20 | \
    while IFS= read -r f; do
      echo "  $(basename "$f")  $(du -sh "$f" | cut -f1)"
    done
}

verify_backup() {
  echo "=== Verifying backups ==="
  find "$BACKUP_DIR" -name "*.tar.gz" | while IFS= read -r f; do
    if tar tzf "$f" &>/dev/null; then
      echo "  ✅ $(basename "$f")"
    else
      echo "  ❌ CORRUPT: $(basename "$f")"
    fi
  done
}

# Main
if [[ "${LIST:-}" == "true" ]]; then
  list_backups; exit 0
fi

if [[ "${VERIFY:-}" == "true" ]]; then
  verify_backup; exit 0
fi

echo "=== HomeLab Backup — $DATE ==="
echo "Target: $TARGET | Mode: ${DRY_RUN:+DRY RUN}${DRY_RUN:-live}"
echo ""

STACKS=("base" "databases" "sso" "monitoring" "ai" "media" "storage" "productivity")

if [[ "$TARGET" == "all" ]]; then
  for stack in "${STACKS[@]}"; do
    [[ -f "stacks/$stack/docker-compose.yml" ]] && backup_volumes "$stack" || true
  done
else
  backup_volumes "$TARGET"
fi

# Prune old
if ! $DRY_RUN; then
  echo ""
  echo "Pruning backups older than $RETAIN_DAYS days..."
  find "$BACKUP_DIR" -name "*.tar.gz" -mtime +"$RETAIN_DAYS" -delete
fi

echo ""
echo "✅ Backup complete"
notify "✅ HomeLab backup complete ($TARGET) — $DATE"
