#!/usr/bin/env bash
# =============================================================================
# Restic Automated Backup Script
# Called by cron inside the restic-backup container.
# Performs: pre-hooks (db dumps) -> backup -> verify -> prune -> offsite copy
#           -> post-hooks (notifications)
# =============================================================================
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_PREFIX="[restic-backup]"
HOOKS_DIR="/hooks"
DB_DUMP_DIR="/db-dumps"
BACKUP_STATUS="success"
BACKUP_ERRORS=""

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log_info()  { echo "$(date '+%Y-%m-%d %H:%M:%S') ${LOG_PREFIX} [INFO]  $*"; }
log_warn()  { echo "$(date '+%Y-%m-%d %H:%M:%S') ${LOG_PREFIX} [WARN]  $*"; }
log_error() { echo "$(date '+%Y-%m-%d %H:%M:%S') ${LOG_PREFIX} [ERROR] $*" >&2; }

# ---------------------------------------------------------------------------
# Notification helper
# ---------------------------------------------------------------------------
send_notification() {
  local title="$1"
  local message="$2"
  local priority="${3:-default}"

  # ntfy / generic webhook
  if [[ -n "${BACKUP_NOTIFY_URL:-}" ]]; then
    curl -sf -X POST "${BACKUP_NOTIFY_URL}" \
      -H "Title: ${title}" \
      -H "Priority: ${priority}" \
      -H "Tags: floppy_disk" \
      -d "${message}" 2>/dev/null || log_warn "Notification send failed"
  fi

  # Email via msmtp (if configured in container)
  if [[ -n "${BACKUP_NOTIFY_EMAIL:-}" ]] && command -v msmtp &>/dev/null; then
    echo -e "Subject: ${title}\n\n${message}" | \
      msmtp "${BACKUP_NOTIFY_EMAIL}" 2>/dev/null || log_warn "Email send failed"
  fi
}

# ---------------------------------------------------------------------------
# Pre-backup hooks: Database dumps
# ---------------------------------------------------------------------------
run_pre_hooks() {
  log_info "Running pre-backup hooks..."
  mkdir -p "$DB_DUMP_DIR"

  # PostgreSQL dump
  if [[ -n "${BACKUP_POSTGRES_CONTAINER:-}" ]] && [[ -n "${POSTGRES_PASSWORD:-}" ]]; then
    log_info "Dumping PostgreSQL from ${BACKUP_POSTGRES_CONTAINER}..."
    if docker exec "${BACKUP_POSTGRES_CONTAINER}" \
      sh -c "PGPASSWORD='${POSTGRES_PASSWORD}' pg_dumpall -U postgres" \
      | gzip > "${DB_DUMP_DIR}/postgres_${TIMESTAMP}.sql.gz" 2>/dev/null; then
      log_info "PostgreSQL dump OK ($(du -sh "${DB_DUMP_DIR}/postgres_${TIMESTAMP}.sql.gz" | cut -f1))"
    else
      log_warn "PostgreSQL dump failed — continuing without it"
      rm -f "${DB_DUMP_DIR}/postgres_${TIMESTAMP}.sql.gz"
    fi
  fi

  # MariaDB/MySQL dump
  if [[ -n "${BACKUP_MARIADB_CONTAINER:-}" ]] && [[ -n "${MARIADB_ROOT_PASSWORD:-}" ]]; then
    log_info "Dumping MariaDB from ${BACKUP_MARIADB_CONTAINER}..."
    if docker exec "${BACKUP_MARIADB_CONTAINER}" \
      sh -c "mariadb-dump --all-databases -u root -p'${MARIADB_ROOT_PASSWORD}'" \
      | gzip > "${DB_DUMP_DIR}/mariadb_${TIMESTAMP}.sql.gz" 2>/dev/null; then
      log_info "MariaDB dump OK ($(du -sh "${DB_DUMP_DIR}/mariadb_${TIMESTAMP}.sql.gz" | cut -f1))"
    else
      log_warn "MariaDB dump failed — continuing without it"
      rm -f "${DB_DUMP_DIR}/mariadb_${TIMESTAMP}.sql.gz"
    fi
  fi

  # Custom pre-hooks
  if [[ -d "${HOOKS_DIR}/pre-backup.d" ]]; then
    for hook in "${HOOKS_DIR}/pre-backup.d"/*.sh; do
      [[ -x "$hook" ]] && {
        log_info "Running pre-hook: $(basename "$hook")"
        "$hook" || log_warn "Pre-hook $(basename "$hook") failed"
      }
    done
  fi

  # Clean old dumps (keep last 3)
  ls -t "${DB_DUMP_DIR}"/postgres_*.sql.gz 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null || true
  ls -t "${DB_DUMP_DIR}"/mariadb_*.sql.gz 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Main backup
# ---------------------------------------------------------------------------
run_backup() {
  log_info "Starting restic backup..."

  local backup_args=(
    --verbose
    --tag "automated"
    --tag "$(date +%A | tr '[:upper:]' '[:lower:]')"
    --host "homelab"
  )

  # Backup source directories
  restic backup "${backup_args[@]}" /source /db-dumps 2>&1 || {
    BACKUP_STATUS="failed"
    BACKUP_ERRORS="${BACKUP_ERRORS}\nBackup command failed"
    log_error "Restic backup FAILED"
    return 1
  }

  log_info "Backup completed successfully"
}

# ---------------------------------------------------------------------------
# Verify backup integrity
# ---------------------------------------------------------------------------
verify_backup() {
  log_info "Verifying latest snapshot integrity..."

  if restic check --read-data-subset=5% 2>&1; then
    log_info "Integrity check PASSED"
  else
    BACKUP_STATUS="warning"
    BACKUP_ERRORS="${BACKUP_ERRORS}\nIntegrity check failed"
    log_warn "Integrity check had errors (non-fatal)"
  fi
}

# ---------------------------------------------------------------------------
# Apply retention policy (prune)
# ---------------------------------------------------------------------------
run_prune() {
  log_info "Applying retention policy..."

  restic forget \
    --keep-hourly  "${RESTIC_KEEP_HOURLY:-24}" \
    --keep-daily   "${RESTIC_KEEP_DAILY:-7}" \
    --keep-weekly  "${RESTIC_KEEP_WEEKLY:-4}" \
    --keep-monthly "${RESTIC_KEEP_MONTHLY:-12}" \
    --keep-yearly  "${RESTIC_KEEP_YEARLY:-3}" \
    --prune \
    --verbose 2>&1 || log_warn "Prune had errors"

  log_info "Retention policy applied"
}

# ---------------------------------------------------------------------------
# Offsite copy (3-2-1 offsite leg)
# ---------------------------------------------------------------------------
run_offsite_copy() {
  if [[ -z "${RESTIC_OFFSITE_REPO:-}" ]]; then
    log_info "No offsite repo configured — skipping offsite copy"
    return 0
  fi

  log_info "Copying latest snapshot to offsite: ${RESTIC_OFFSITE_REPO}"

  # Use restic copy to replicate to offsite repo
  RESTIC_PASSWORD2="${RESTIC_OFFSITE_PASSWORD:-${RESTIC_PASSWORD}}" \
  AWS_ACCESS_KEY_ID="${AWS_OFFSITE_ACCESS_KEY_ID:-}" \
  AWS_SECRET_ACCESS_KEY="${AWS_OFFSITE_SECRET_ACCESS_KEY:-}" \
  restic -r "${RESTIC_OFFSITE_REPO}" copy --from-repo "${RESTIC_REPOSITORY}" 2>&1 || {
    BACKUP_STATUS="warning"
    BACKUP_ERRORS="${BACKUP_ERRORS}\nOffsite copy failed"
    log_warn "Offsite copy failed (non-fatal)"
  }

  log_info "Offsite copy complete"
}

# ---------------------------------------------------------------------------
# Post-backup hooks
# ---------------------------------------------------------------------------
run_post_hooks() {
  # Custom post-hooks
  if [[ -d "${HOOKS_DIR}/post-backup.d" ]]; then
    for hook in "${HOOKS_DIR}/post-backup.d"/*.sh; do
      [[ -x "$hook" ]] && {
        log_info "Running post-hook: $(basename "$hook")"
        "$hook" || log_warn "Post-hook $(basename "$hook") failed"
      }
    done
  fi
}

# ---------------------------------------------------------------------------
# Generate summary and notify
# ---------------------------------------------------------------------------
send_summary() {
  local snapshot_info
  snapshot_info=$(restic snapshots --latest 1 --json 2>/dev/null | head -c 1000 || echo "N/A")

  local repo_stats
  repo_stats=$(restic stats --json 2>/dev/null | head -c 500 || echo "N/A")

  local summary="Backup Status: ${BACKUP_STATUS}
Time: ${TIMESTAMP}
Repository: ${RESTIC_REPOSITORY}
Latest Snapshot: ${snapshot_info}
Repository Stats: ${repo_stats}"

  if [[ -n "${BACKUP_ERRORS}" ]]; then
    summary="${summary}\n\nErrors/Warnings:\n${BACKUP_ERRORS}"
  fi

  local priority="default"
  local title="Homelab Backup OK"
  if [[ "$BACKUP_STATUS" == "failed" ]]; then
    priority="high"
    title="Homelab Backup FAILED"
  elif [[ "$BACKUP_STATUS" == "warning" ]]; then
    priority="high"
    title="Homelab Backup WARNING"
  fi

  send_notification "$title" "$summary" "$priority"
  log_info "Backup run complete — status: ${BACKUP_STATUS}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
log_info "========== Backup started: ${TIMESTAMP} =========="

run_pre_hooks
run_backup
verify_backup
run_prune
run_offsite_copy
run_post_hooks
send_summary

log_info "========== Backup finished: $(date +%Y%m%d_%H%M%S) =========="
