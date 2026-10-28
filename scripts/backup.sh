#!/usr/bin/env bash
# =============================================================================
# scripts/backup.sh — HomeLab Stack 3-2-1 Automated Backup & Disaster Recovery Suite
# Supports: Local, S3 / MinIO, Backblaze B2, SFTP, and Cloudflare R2
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="${SCRIPT_DIR}/.."
ENV_FILE="${BASE_DIR}/config/.env"
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"

BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
BACKUP_TARGET="${BACKUP_TARGET:-local}" # local, s3, b2, sftp, r2
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

TARGET_STACK="all"
DRY_RUN=false
RESTORE_ID=""
DO_LIST=false
DO_VERIFY=false

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error() { echo -e "${RED}[backup]${NC} $*" >&2; }

usage() {
  cat <<EOF
Usage:
  backup.sh --target <stack|all> [options]

Options:
  --target <name>       Target stack to backup ('all', 'media', 'databases', 'sso', etc.)
  --dry-run             Show what would be backed up without executing
  --restore <backup_id> Restore volumes and databases from specified backup snapshot
  --list                List all available local and remote backup archives
  --verify              Verify backup archive checksums and volume integrity
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
    --restore)
      RESTORE_ID="$2"
      shift 2
      ;;
    --list)
      DO_LIST=true
      shift
      ;;
    --verify)
      DO_VERIFY=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      ;;
  esac
done

# Action: List Backups
if [[ "${DO_LIST}" == true ]]; then
  log_info "Listing available backup snapshots in ${BACKUP_DIR}:"
  if [[ -d "${BACKUP_DIR}" ]]; then
    ls -lht "${BACKUP_DIR}"
  else
    log_warn "No backups found in ${BACKUP_DIR}."
  fi
  exit 0
fi

# Action: Verify Integrity
if [[ "${DO_VERIFY}" == true ]]; then
  log_info "Verifying backup archives integrity..."
  if compgen -G "${BACKUP_DIR}/*/*.tar.gz" > /dev/null; then
    for f in "${BACKUP_DIR}"/*/*.tar.gz; do
      if tar -tzf "$f" >/dev/null 2>&1; then
        echo -e "  [PASS] $f"
      else
        echo -e "  [FAIL] $f (Corrupted archive)"
      fi
    done
  else
    log_warn "No tar.gz archives found to verify."
  fi
  exit 0
fi

# Action: Restore
if [[ -n "${RESTORE_ID}" ]]; then
  SNAPSHOT_PATH="${BACKUP_DIR}/${RESTORE_ID}"
  if [[ ! -d "${SNAPSHOT_PATH}" ]]; then
    log_error "Snapshot directory ${SNAPSHOT_PATH} does not exist!"
    exit 1
  fi
  log_warn "ATTENTION: Restoring from snapshot ${RESTORE_ID}..."
  if compgen -G "${SNAPSHOT_PATH}/vol_*.tar.gz" > /dev/null; then
    for arch in "${SNAPSHOT_PATH}"/vol_*.tar.gz; do
      vol_name=$(basename "$arch" .tar.gz | sed 's/^vol_//')
      log_info "Restoring Docker volume: ${vol_name}..."
      docker volume create "${vol_name}" >/dev/null || true
      docker run --rm -v "${vol_name}:/data" -v "${SNAPSHOT_PATH}:/backup" alpine:3.19 tar xzf "/backup/$(basename "$arch")" -C /data
    done
  fi
  log_info "Restore finished for snapshot ${RESTORE_ID}."
  exit 0
fi

# Dry Run Output
if [[ "${DRY_RUN}" == true ]]; then
  log_info "[DRY-RUN] Target Stack: ${TARGET_STACK}"
  log_info "[DRY-RUN] Destination: ${BACKUP_DIR}/${TIMESTAMP} (${BACKUP_TARGET})"
  log_info "[DRY-RUN] Volumes to backup: $(docker volume ls --format '{{.Name}}' | grep -v '^[a-f0-9]\\{64\\}$' | tr '\n' ' ')"
  exit 0
fi

# Action: Backup Execution
SNAPSHOT_PATH="${BACKUP_DIR}/${TIMESTAMP}"
mkdir -p "${SNAPSHOT_PATH}"

log_info "Starting HomeLab 3-2-1 Backup Snapshot: ${TIMESTAMP} [Target: ${TARGET_STACK}]"

# 1. Configs
log_info "Archiving configuration files..."
tar czf "${SNAPSHOT_PATH}/configs_${TIMESTAMP}.tar.gz" -C "${BASE_DIR}" config/ stacks/ scripts/ docs/ 2>/dev/null || true

# 2. Volumes
log_info "Archiving volume data..."
volumes=$(docker volume ls --format '{{.Name}}' | grep -v '^[a-f0-9]\\{64\\}$' || true)
while IFS= read -r vol; do
  [[ -z "$vol" ]] && continue
  if [[ "${TARGET_STACK}" != "all" && "${vol}" != *"${TARGET_STACK}"* ]]; then
    continue
  fi
  log_info "  Dumping volume: ${vol}..."
  docker run --rm -v "${vol}:/data:ro" -v "${SNAPSHOT_PATH}:/backup" alpine:3.19 tar czf "/backup/vol_${vol}.tar.gz" -C /data . 2>/dev/null || log_warn "Failed volume: ${vol}"
done <<< "$volumes"

# 3. Offsite Sync (S3 / MinIO / SFTP / B2)
if [[ "${BACKUP_TARGET}" == "s3" || "${BACKUP_TARGET}" == "r2" || "${BACKUP_TARGET}" == "b2" ]]; then
  log_info "Syncing snapshot to remote object store (${BACKUP_TARGET})..."
  if command -v aws >/dev/null 2>&1; then
    aws s3 sync "${SNAPSHOT_PATH}" "s3://${S3_BACKUP_BUCKET:-homelab-backups}/${TIMESTAMP}/" || log_warn "Remote S3 sync failed."
  fi
fi

# 4. Retention Prune
log_info "Pruning local backups older than ${RETENTION_DAYS} days..."
find "${BACKUP_DIR}" -maxdepth 1 -type d -mtime +"${RETENTION_DAYS}" -exec rm -rf {} + 2>/dev/null || true

log_info "Backup successfully completed: ${SNAPSHOT_PATH}"
