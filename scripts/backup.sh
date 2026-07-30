#!/usr/bin/env bash
set -euo pipefail

# ════════════════════════════════════════════════════════════════
# backup.sh — 3-2-1 Backup Strategy with Restic
# ════════════════════════════════════════════════════════════════
# Usage:
#   backup.sh --target all                       # Backup everything
#   backup.sh --target media                      # Backup specific stack
#   backup.sh --target all --dry-run              # Preview only
#   backup.sh --restore <snapshot_id> [--target <stack>]
#   backup.sh --list [--target <stack>]
#   backup.sh --verify [--target <stack>]
# ════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../stacks/backup/.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# Defaults
TARGET=""
DRY_RUN=false
RESTORE_ID=""
LIST_MODE=false
VERIFY_MODE=false

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)   TARGET="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --restore)  RESTORE_ID="$2"; shift 2 ;;
    --list)     LIST_MODE=true; shift ;;
    --verify)   VERIFY_MODE=true; shift ;;
    --help|-h)
      echo "Usage: backup.sh --target <stack|all> [options]"
      echo ""
      echo "Options:"
      echo "  --target <name>    Backup target: all, base, media, storage, monitoring,"
      echo "                     network, productivity, ai, sso, databases, notifications"
      echo "  --dry-run          Show what would be backed up without executing"
      echo "  --restore <id>     Restore from snapshot ID"
      echo "  --list             List all backups"
      echo "  --verify           Verify backup integrity"
      echo "  --help             Show this help"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Config ─────────────────────────────────────────────────────
REPO="${RESTIC_REPOSITORY:-rest:http://restic-server:8000/}"
PASS="${RESTIC_PASSWORD:-}"
KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-6}"
KEEP_YEARLY="${KEEP_YEARLY:-1}"
NTFY_URL="${NTFY_URL:-}"
NTFY_TOPIC="${NTFY_TOPIC:-homelab-backups}"

export RESTIC_REPOSITORY="$REPO"
export RESTIC_PASSWORD="$PASS"

# ── Stack path mapping ────────────────────────────────────────
declare -A STACK_PATHS=(
  ["base"]="${STACK_BASE:-/data/base}"
  ["media"]="${STACK_MEDIA:-/data/media}"
  ["storage"]="${STACK_STORAGE:-/data/storage}"
  ["monitoring"]="${STACK_MONITORING:-/data/monitoring}"
  ["network"]="${STACK_NETWORK:-/data/network}"
  ["productivity"]="${STACK_PRODUCTIVITY:-/data/productivity}"
  ["ai"]="${STACK_AI:-/data/ai}"
  ["sso"]="${STACK_SSO:-/data/sso}"
  ["databases"]="${STACK_DATABASES:-/data/databases}"
  ["notifications"]="${STACK_NOTIFICATIONS:-/data/notifications}"
)

ALL_STACKS=("base" "media" "storage" "monitoring" "network" "productivity" "ai" "sso" "databases" "notifications")

# ── Notification ──────────────────────────────────────────────
notify() {
  local title="$1" message="$2" priority="${3:-default}"
  if [[ -z "$NTFY_URL" ]]; then return 0; fi
  curl -sf -X POST \
    -H "Title: ${title}" \
    -H "Priority: ${priority}" \
    -H "Tags: backup" \
    -d "$message" \
    "${NTFY_URL}/${NTFY_TOPIC}" 2>/dev/null || true
}

# ── Restic helper ──────────────────────────────────────────────
restic_cmd() {
  if $DRY_RUN; then
    echo "[DRY-RUN] restic $*"
  else
    restic "$@"
  fi
}

# ── Init repo if needed ───────────────────────────────────────
init_repo() {
  if ! restic snapshots &>/dev/null; then
    echo "[INFO] Initializing restic repository..."
    restic init
    echo "[OK] Repository initialized"
  fi
}

# ── Backup ─────────────────────────────────────────────────────
do_backup() {
  local stack="$1"
  local path="${STACK_PATHS[$stack]:-}"

  if [[ -z "$path" ]]; then
    echo "[WARN] No path defined for stack: $stack"
    return 1
  fi

  echo "── Backing up: ${stack} (${path}) ──"

  if [[ ! -d "$path" ]]; then
    echo "[WARN] Path does not exist: $path — skipping"
    return 0
  fi

  local tags="--tag ${stack}"
  restic_cmd backup "$path" $tags --verbose

  if $DRY_RUN; then
    echo "  [DRY-RUN] Would backup ${path} with tag '${stack}'"
  else
    echo "  [OK] Backed up: ${stack}"
  fi
}

run_backup() {
  init_repo
  local stacks_to_backup=()

  if [[ "$TARGET" == "all" ]]; then
    stacks_to_backup=("${ALL_STACKS[@]}")
  else
    stacks_to_backup=("$TARGET")
  fi

  echo "═══════════════════════════════════════════════════"
  echo "  Backup Started: $(date)"
  echo "  Target: ${TARGET}"
  echo "  Mode: $([[ $DRY_RUN == true ]] && echo 'DRY-RUN' || echo 'LIVE')"
  echo "═══════════════════════════════════════════════════"

  local failed=0
  for stack in "${stacks_to_backup[@]}"; do
    do_backup "$stack" || ((failed++))
  done

  # Prune old snapshots
  if ! $DRY_RUN; then
    echo ""
    echo "── Pruning old snapshots ──"
    restic forget \
      --keep-daily "$KEEP_DAILY" \
      --keep-weekly "$KEEP_WEEKLY" \
      --keep-monthly "$KEEP_MONTHLY" \
      --keep-yearly "$KEEP_YEARLY" \
      --prune --verbose
    echo "[OK] Pruned snapshots (daily:${KEEP_DAILY}, weekly:${KEEP_WEEKLY}, monthly:${KEEP_MONTHLY}, yearly:${KEEP_YEARLY})"
  fi

  echo ""
  echo "═══════════════════════════════════════════════════"
  echo "  Backup Complete: $(date)"
  echo "  Failed: ${failed}"
  echo "═══════════════════════════════════════════════════"

  if [[ $failed -gt 0 ]]; then
    notify "Backup FAILED" "${failed} stack(s) failed backup" "high"
    return 1
  else
    notify "Backup OK" "All stacks backed up successfully" "default"
    return 0
  fi
}

# ── Restore ────────────────────────────────────────────────────
do_restore() {
  local snapshot_id="$1"
  local target="${TARGET:-all}"
  local restore_path="${RESTORE_PATH:-/tmp/restore-$(date +%s)}"

  echo "═══════════════════════════════════════════════════"
  echo "  Restore Started: $(date)"
  echo "  Snapshot: ${snapshot_id}"
  echo "  Target: ${target}"
  echo "  Restore to: ${restore_path}"
  echo "═══════════════════════════════════════════════════"

  mkdir -p "$restore_path"

  if [[ "$target" == "all" ]]; then
    restic_cmd restore "$snapshot_id" --target "$restore_path"
  else
    restic_cmd restore "$snapshot_id" --target "$restore_path" --tag "$target"
  fi

  if $DRY_RUN; then
    echo "  [DRY-RUN] Would restore snapshot ${snapshot_id} to ${restore_path}"
  else
    echo "  [OK] Restored snapshot ${snapshot_id} to ${restore_path}"
    notify "Restore OK" "Snapshot ${snapshot_id} restored to ${restore_path}" "default"
  fi
}

# ── List ────────────────────────────────────────────────────────
do_list() {
  echo "═══════════════════════════════════════════════════"
  echo "  Available Backups"
  echo "═══════════════════════════════════════════════════"
  if [[ -n "$TARGET" && "$TARGET" != "all" ]]; then
    restic snapshots --tag "$TARGET" --verbose
  else
    restic snapshots --verbose
  fi
}

# ── Verify ──────────────────────────────────────────────────────
do_verify() {
  echo "═══════════════════════════════════════════════════"
  echo "  Verifying Backup Integrity"
  echo "═══════════════════════════════════════════════════"
  if $DRY_RUN; then
    echo "  [DRY-RUN] Would run: restic check"
    return 0
  fi
  restic check --verbose
  local result=$?
  if [[ $result -eq 0 ]]; then
    echo "  [OK] All backups verified successfully"
    notify "Verify OK" "All backups verified successfully" "default"
  else
    echo "  [FAIL] Backup integrity check failed"
    notify "Verify FAILED" "Backup integrity check failed" "high"
    return 1
  fi
}

# ── Main ────────────────────────────────────────────────────────
if [[ -z "$TARGET" && -z "$RESTORE_ID" && -z "$LIST_MODE" && -z "$VERIFY_MODE" ]]; then
  echo "Error: --target is required (or use --list / --verify / --restore)"
  exit 1
fi

if [[ -n "$RESTORE_ID" ]]; then
  do_restore "$RESTORE_ID"
elif $LIST_MODE; then
  do_list
elif $VERIFY_MODE; then
  do_verify
else
  run_backup
fi