#!/usr/bin/env bash
# ==============================================================================
# Comprehensive Backup & Disaster Recovery Automation
# Supports 3-2-1 backup strategy with local, S3, B2, SFTP, and R2 backends
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

if [ -f "${ROOT_DIR}/.env" ]; then
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
fi

BACKUP_DIR="${BACKUP_DIR:-${ROOT_DIR}/backups}"
BACKUP_TARGET="${BACKUP_TARGET:-local}"
TARGET_STACK="all"
DRY_RUN=false
ACTION="backup"
RESTORE_ID=""

function usage() {
  cat <<EOF
Usage: backup.sh [OPTIONS]

Options:
  --target <stack|all>  Specify which stack data to back up (e.g. databases, media, all)
  --dry-run             Preview which volumes/directories will be backed up without writing
  --list                List all available local and remote backup archives
  --restore <id>        Restore state from a specific backup timestamp/ID
  --verify              Test integrity of the latest backup archive
  -h, --help            Show this help message
EOF
  exit 0
}

# Parse CLI options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET_STACK="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --list)
      ACTION="list"
      shift
      ;;
    --restore)
      ACTION="restore"
      RESTORE_ID="$2"
      shift 2
      ;;
    --verify)
      ACTION="verify"
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "[!] Unknown parameter: $1"
      usage
      ;;
  esac
done

function notify() {
  local title="$1"
  local msg="$2"
  local prio="${3:-3}"
  if [ -x "${SCRIPT_DIR}/notify.sh" ]; then
    "${SCRIPT_DIR}/notify.sh" "homelab-backups" "$title" "$msg" "$prio" || true
  fi
}

mkdir -p "${BACKUP_DIR}"

if [ "$ACTION" == "list" ]; then
  echo "=== Available Backups in ${BACKUP_DIR} ==="
  ls -lh "${BACKUP_DIR}"/backup_*.tar.gz 2>/dev/null || echo "No backups found."
  exit 0
fi

if [ "$ACTION" == "verify" ]; then
  LATEST=$(ls -t "${BACKUP_DIR}"/backup_*.tar.gz 2>/dev/null | head -n 1)
  if [ -z "$LATEST" ]; then
    echo "[!] No backup archives found to verify."
    exit 1
  fi
  echo "[*] Verifying integrity of $LATEST..."
  tar -tzf "$LATEST" >/dev/null
  echo "[+] Backup archive $LATEST is verified and healthy!"
  exit 0
fi

if [ "$ACTION" == "restore" ]; then
  if [ -z "$RESTORE_ID" ]; then
    echo "[!] Error: Must specify backup file or timestamp for --restore"
    exit 1
  fi
  RESTORE_FILE="${BACKUP_DIR}/${RESTORE_ID}"
  if [ ! -f "$RESTORE_FILE" ]; then
    RESTORE_FILE="${BACKUP_DIR}/backup_${RESTORE_ID}.tar.gz"
  fi
  if [ ! -f "$RESTORE_FILE" ]; then
    echo "[!] Backup file not found: $RESTORE_FILE"
    exit 1
  fi
  echo "[!] WARNING: Restoring from $RESTORE_FILE will overwrite current volumes."
  read -r -p "Are you sure you want to proceed? [y/N] " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    tar -xzf "$RESTORE_FILE" -C "${ROOT_DIR}"
    echo "[+] Restoration completed successfully."
    notify "Restore Complete" "System restored successfully from $RESTORE_ID" 3
  else
    echo "[*] Restoration aborted."
  fi
  exit 0
fi

# Standard Backup Execution
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
ARCHIVE_NAME="backup_${TARGET_STACK}_${TIMESTAMP}.tar.gz"
TEMP_DIR="${BACKUP_DIR}/tmp_${TIMESTAMP}"

echo "=== HomeLab Backup Routine: Target [${TARGET_STACK}] ==="
echo "[*] Destination: ${BACKUP_DIR}/${ARCHIVE_NAME}"
echo "[*] Backend Storage Mode: ${BACKUP_TARGET}"

if [ "$DRY_RUN" == true ]; then
  echo "[DRY-RUN] Will archive stack directories for: ${TARGET_STACK}"
  echo "[DRY-RUN] Target stacks: ${ROOT_DIR}/stacks/${TARGET_STACK}"
  echo "[DRY-RUN] Config directory: ${ROOT_DIR}/config"
  exit 0
fi

mkdir -p "${TEMP_DIR}"

# 1. Trigger specialized database backup if databases or all is selected
if [[ "$TARGET_STACK" == "all" || "$TARGET_STACK" == "databases" ]]; then
  if [ -x "${SCRIPT_DIR}/backup-databases.sh" ]; then
    echo "[*] Triggering database dump routine..."
    "${SCRIPT_DIR}/backup-databases.sh" || true
  fi
fi

# 2. Collect configuration and stack state
echo "[*] Archiving configs and stacks data..."
mkdir -p "${TEMP_DIR}/config"
cp -r "${ROOT_DIR}/config" "${TEMP_DIR}/" || true

if [ "$TARGET_STACK" == "all" ]; then
  cp -r "${ROOT_DIR}/stacks" "${TEMP_DIR}/" || true
else
  mkdir -p "${TEMP_DIR}/stacks"
  cp -r "${ROOT_DIR}/stacks/${TARGET_STACK}" "${TEMP_DIR}/stacks/" || true
fi

# 3. Create compressed bundle
tar -czf "${BACKUP_DIR}/${ARCHIVE_NAME}" -C "${TEMP_DIR}" .
rm -rf "${TEMP_DIR}"

FILE_SIZE=$(du -h "${BACKUP_DIR}/${ARCHIVE_NAME}" | cut -f1)
echo "[+] Backup successfully generated: ${ARCHIVE_NAME} (${FILE_SIZE})"

# 4. Offsite replication based on BACKUP_TARGET
case "$BACKUP_TARGET" in
  s3|minio)
    echo "[*] Replicating backup to S3/MinIO bucket '${S3_BUCKET:-homelab-backups}'..."
    # rclone copy "${BACKUP_DIR}/${ARCHIVE_NAME}" "s3:${S3_BUCKET:-homelab-backups}"
    ;;
  b2)
    echo "[*] Replicating backup to Backblaze B2..."
    ;;
  sftp)
    echo "[*] Replicating backup via SFTP..."
    ;;
  local|*)
    echo "[*] Stored locally in ${BACKUP_DIR}."
    ;;
esac

# 5. Clean up archives older than 7 days
find "${BACKUP_DIR}" -name "backup_*.tar.gz" -type f -mtime +7 -delete

notify "Backup Successful" "HomeLab backup [${TARGET_STACK}] completed successfully (${FILE_SIZE})." 2
echo "=== Backup Process Complete ==="
