#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup & Disaster Recovery Script
# Supports: Duplicati + Restic with 3-2-1 backup strategy
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${BACKUP_ROOT:-/backups}"
LOG_FILE="${BACKUP_ROOT}/backup.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"; exit 1; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --target TARGET    Backup target: duplicati|restic|all (default: all)
  --dry-run          Show what would be backed up without executing
  --restore          Restore mode: --restore TARGET SNAPSHOT_ID
  --list             List available backups/snapshots
  --verify           Verify backup integrity
  --cleanup          Remove old backups per retention policy
  -h, --help         Show this help

Examples:
  $(basename "$0")                        # Full backup (all targets)
  $(basename "$0") --target restic        # Restic-only backup
  $(basename "$0") --dry-run              # Preview backup
  $(basename "$0") --list                 # List snapshots
  $(basename "$0") --verify               # Verify integrity
  $(basename "$0") --restore restic abc123  # Restore snapshot
  $(basename "$0") --cleanup              # Apply retention policy
EOF
    exit 0
}

# Defaults
TARGET="all"
DRY_RUN=false
ACTION="backup"
RESTORE_SNAPSHOT=""
RETENTION_DAILY=7
RETENTION_WEEKLY=4
RETENTION_MONTHLY=12

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --restore) ACTION="restore"; RESTORE_SNAPSHOT="$3"; TARGET="$2"; shift 3 ;;
        --list) ACTION="list"; shift ;;
        --verify) ACTION="verify"; shift ;;
        --cleanup) ACTION="cleanup"; shift ;;
        -h|--help) usage ;;
        *) error "Unknown option: $1" ;;
    esac
done

mkdir -p "$BACKUP_ROOT"/{duplicati,restic}

# =============================================================================
# Restic Functions
# =============================================================================
restic_init() {
    if [[ ! -d "$BACKUP_ROOT/restic/repo" ]]; then
        log "Initializing Restic repository..."
        restic init --repo "$BACKUP_ROOT/restic/repo" 2>/dev/null || true
    fi
}

restic_backup() {
    log "Starting Restic backup..."
    local source="${STORAGE_PATH:-/data}"
    local args=(--repo "$BACKUP_ROOT/restic/repo" backup "$source" --verbose)

    if $DRY_RUN; then
        args+=(--dry-run)
        warn "DRY RUN — no data will be backed up"
    fi

    restic "${args[@]}" 2>&1 | tee -a "$LOG_FILE"
    log "Restic backup completed."
}

restic_list() {
    log "Listing Restic snapshots..."
    restic --repo "$BACKUP_ROOT/restic/repo" snapshots 2>&1 | tee -a "$LOG_FILE"
}

restic_verify() {
    log "Verifying Restic repository..."
    restic --repo "$BACKUP_ROOT/restic/repo" check --read-data-subset=5% 2>&1 | tee -a "$LOG_FILE"
    log "Verification complete."
}

restic_restore() {
    [[ -z "$RESTORE_SNAPSHOT" ]] && error "Snapshot ID required for restore"
    local restore_dir="${RESTORE_DIR:-/restore}"
    log "Restoring snapshot $RESTORE_SNAPSHOT to $restore_dir..."
    restic --repo "$BACKUP_ROOT/restic/repo" restore "$RESTORE_SNAPSHOT" --target "$restore_dir" 2>&1 | tee -a "$LOG_FILE"
    log "Restore completed."
}

restic_cleanup() {
    log "Applying Restic retention policy (daily=$RETENTION_DAILY, weekly=$RETENTION_WEEKLY, monthly=$RETENTION_MONTHLY)..."
    restic --repo "$BACKUP_ROOT/restic/repo" forget \
        --keep-daily "$RETENTION_DAILY" \
        --keep-weekly "$RETENTION_WEEKLY" \
        --keep-monthly "$RETENTION_MONTHLY" \
        --prune 2>&1 | tee -a "$LOG_FILE"
    log "Cleanup complete."
}

# =============================================================================
# Duplicati Functions (via API)
# =============================================================================
DUPLICATI_URL="${DUPLICATI_URL:-http://duplicati:8200}"

duplicati_backup() {
    log "Triggering Duplicati backup via API..."
    if $DRY_RUN; then
        warn "DRY RUN — Duplicati backup not triggered"
        return
    fi
    curl -s -X POST "$DUPLICATI_URL/api/v1/backup/1/run" 2>&1 | tee -a "$LOG_FILE" || warn "Duplicati API call failed (service may not be running)"
    log "Duplicati backup triggered."
}

duplicati_list() {
    log "Listing Duplicati backups..."
    curl -s "$DUPLICATI_URL/api/v1/backup/1" 2>&1 | python3 -m json.tool 2>/dev/null | tee -a "$LOG_FILE" || warn "Cannot reach Duplicati API"
}

duplicati_verify() {
    log "Verifying Duplicati backups..."
    curl -s -X POST "$DUPLICATI_URL/api/v1/backup/1/verify" 2>&1 | tee -a "$LOG_FILE" || warn "Duplicati API call failed"
    log "Verification triggered."
}

# =============================================================================
# Main Dispatch
# =============================================================================
run_for_target() {
    local target="$1"
    case "$ACTION" in
        backup)
            case "$target" in
                restic) restic_init; restic_backup ;;
                duplicati) duplicati_backup ;;
                all) restic_init; restic_backup; duplicati_backup ;;
                *) error "Unknown target: $target" ;;
            esac
            ;;
        list)
            case "$target" in
                restic) restic_list ;;
                duplicati) duplicati_list ;;
                all) restic_list; duplicati_list ;;
            esac
            ;;
        verify)
            case "$target" in
                restic) restic_verify ;;
                duplicati) duplicati_verify ;;
                all) restic_verify; duplicati_verify ;;
            esac
            ;;
        restore)
            case "$target" in
                restic) restic_restore ;;
                duplicati) warn "Duplicati restore via CLI not supported — use web UI" ;;
                *) error "Unknown target: $target" ;;
            esac
            ;;
        cleanup)
            case "$target" in
                restic) restic_cleanup ;;
                duplicati) warn "Duplicati retention managed via web UI" ;;
                all) restic_cleanup ;;
            esac
            ;;
    esac
}

log "=== HomeLab Backup — $ACTION (target=$TARGET) ==="
run_for_target "$TARGET"
log "=== Done ==="
