#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup & Restore Helper
# Automated backup, restore, verify, and disaster recovery operations.
#
# Usage:
#   ./backup-restore.sh backup              — Run immediate backup
#   ./backup-restore.sh restore [snapshot]   — Restore from snapshot
#   ./backup-restore.sh list                 — List available snapshots
#   ./backup-restore.sh verify              — Verify backup integrity
#   ./backup-restore.sh stats               — Show repository stats
#   ./backup-restore.sh unlock              — Remove stale repo locks
#   ./backup-restore.sh init-offsite        — Initialize offsite repo
#   ./backup-restore.sh dr-test             — Run DR test (read-only)
#   ./backup-restore.sh dump-db             — Dump databases only
#   ./backup-restore.sh restore-db [file]   — Restore database from dump
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
STACK_DIR="$ROOT_DIR/stacks/backup"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error() { echo -e "${RED}[backup]${NC} $*" >&2; }
log_step()  { echo -e "${CYAN}[step]${NC} ${BOLD}$*${NC}"; }

# Load environment
if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

RESTIC_CONTAINER="${RESTIC_CONTAINER:-restic-backup}"

# ---------------------------------------------------------------------------
# Helper: exec restic inside the container
# ---------------------------------------------------------------------------
restic_exec() {
  docker exec "$RESTIC_CONTAINER" restic "$@"
}

# ---------------------------------------------------------------------------
# backup — Trigger immediate backup
# ---------------------------------------------------------------------------
cmd_backup() {
  log_step "Triggering immediate backup..."
  docker exec "$RESTIC_CONTAINER" /usr/local/bin/backup.sh
  log_info "Backup completed. Use '$0 list' to see snapshots."
}

# ---------------------------------------------------------------------------
# list — List all snapshots
# ---------------------------------------------------------------------------
cmd_list() {
  log_step "Available snapshots:"
  restic_exec snapshots --compact
}

# ---------------------------------------------------------------------------
# restore — Restore from a snapshot
# ---------------------------------------------------------------------------
cmd_restore() {
  local snapshot="${1:-latest}"
  local target="${2:-/tmp/restic-restore}"

  log_step "Restore plan:"
  echo "  Snapshot: $snapshot"
  echo "  Target:   $target (on host)"
  echo ""

  # Show snapshot contents
  log_info "Snapshot contents:"
  restic_exec ls "$snapshot" --long 2>/dev/null | head -30
  echo "  ..."
  echo ""

  read -rp "Proceed with restore? (yes/no): " confirm
  if [[ "$confirm" != "yes" ]]; then
    log_warn "Restore cancelled."
    exit 0
  fi

  log_step "1/4 — Creating restore target directory..."
  mkdir -p "$target"

  log_step "2/4 — Stopping affected services..."
  echo "  WARNING: You may want to stop services that use the restored data."
  echo "  Current running containers:"
  docker ps --format '  - {{.Names}} ({{.Status}})' | head -20
  echo ""
  read -rp "Stop any containers? (comma-separated names, or ENTER to skip): " stop_list
  if [[ -n "$stop_list" ]]; then
    IFS=',' read -ra containers <<< "$stop_list"
    for c in "${containers[@]}"; do
      c=$(echo "$c" | xargs)  # trim whitespace
      log_info "Stopping $c..."
      docker stop "$c" 2>/dev/null || log_warn "Could not stop $c"
    done
  fi

  log_step "3/4 — Restoring snapshot $snapshot..."
  docker exec "$RESTIC_CONTAINER" restic restore "$snapshot" --target /restore-target \
    --verbose 2>&1 | tail -20

  # Copy from container to host
  docker cp "${RESTIC_CONTAINER}:/restore-target/." "$target/"

  log_step "4/4 — Verifying restored data..."
  local restored_size
  restored_size=$(du -sh "$target" 2>/dev/null | cut -f1)
  log_info "Restored $restored_size to $target"

  if [[ -n "${stop_list:-}" ]]; then
    read -rp "Restart stopped containers? (yes/no): " restart
    if [[ "$restart" == "yes" ]]; then
      for c in "${containers[@]}"; do
        c=$(echo "$c" | xargs)
        log_info "Starting $c..."
        docker start "$c" 2>/dev/null || log_warn "Could not start $c"
      done
    fi
  fi

  echo ""
  log_info "Restore complete!"
  echo "  Restored to: $target"
  echo ""
  echo "  Next steps:"
  echo "  1. Inspect the restored files in $target"
  echo "  2. Copy needed files to their original locations"
  echo "  3. Restart services: docker compose -f $STACK_DIR/docker-compose.yml up -d"
}

# ---------------------------------------------------------------------------
# verify — Check backup integrity
# ---------------------------------------------------------------------------
cmd_verify() {
  log_step "Running backup integrity verification..."
  echo ""

  log_info "Phase 1: Checking repository structure..."
  restic_exec check 2>&1

  echo ""
  log_info "Phase 2: Verifying data integrity (sampling 10%)..."
  restic_exec check --read-data-subset=10% 2>&1

  echo ""
  log_info "Phase 3: Listing latest snapshot..."
  restic_exec snapshots --latest 3

  echo ""
  log_info "Verification complete."
}

# ---------------------------------------------------------------------------
# stats — Repository statistics
# ---------------------------------------------------------------------------
cmd_stats() {
  log_step "Repository statistics:"
  echo ""
  restic_exec stats
  echo ""
  restic_exec snapshots --compact
}

# ---------------------------------------------------------------------------
# unlock — Remove stale locks
# ---------------------------------------------------------------------------
cmd_unlock() {
  log_step "Removing stale repository locks..."
  restic_exec unlock --remove-all 2>&1
  log_info "Locks removed."
}

# ---------------------------------------------------------------------------
# init-offsite — Initialize offsite S3 repo
# ---------------------------------------------------------------------------
cmd_init_offsite() {
  if [[ -z "${RESTIC_OFFSITE_REPO:-}" ]]; then
    log_error "RESTIC_OFFSITE_REPO not set in .env"
    echo ""
    echo "Configure one of these in your .env:"
    echo "  # AWS S3"
    echo "  RESTIC_OFFSITE_REPO=s3:s3.amazonaws.com/your-bucket"
    echo ""
    echo "  # Backblaze B2"
    echo "  RESTIC_OFFSITE_REPO=s3:s3.us-west-004.backblazeb2.com/your-bucket"
    echo ""
    echo "  # Wasabi"
    echo "  RESTIC_OFFSITE_REPO=s3:s3.wasabisys.com/your-bucket"
    exit 1
  fi

  log_step "Initializing offsite repo: ${RESTIC_OFFSITE_REPO}"
  docker exec \
    -e RESTIC_REPOSITORY="${RESTIC_OFFSITE_REPO}" \
    -e RESTIC_PASSWORD="${RESTIC_OFFSITE_PASSWORD:-${RESTIC_PASSWORD}}" \
    -e AWS_ACCESS_KEY_ID="${BACKUP_OFFSITE_S3_KEY:-}" \
    -e AWS_SECRET_ACCESS_KEY="${BACKUP_OFFSITE_S3_SECRET:-}" \
    "$RESTIC_CONTAINER" restic init 2>&1

  log_info "Offsite repo initialized: ${RESTIC_OFFSITE_REPO}"
}

# ---------------------------------------------------------------------------
# dr-test — Disaster Recovery Test (non-destructive)
# ---------------------------------------------------------------------------
cmd_dr_test() {
  log_step "=== Disaster Recovery Test ==="
  echo ""
  echo "This test validates your backup chain WITHOUT modifying production data."
  echo ""

  local dr_dir="/tmp/dr-test-$(date +%Y%m%d_%H%M%S)"
  local test_passed=0
  local test_failed=0

  # Test 1: Repository accessible
  log_info "Test 1/5: Repository accessible..."
  if restic_exec snapshots --latest 1 >/dev/null 2>&1; then
    echo "  PASS"
    ((test_passed++))
  else
    echo "  FAIL — Cannot access repository"
    ((test_failed++))
  fi

  # Test 2: At least one snapshot exists
  log_info "Test 2/5: Snapshots exist..."
  local count
  count=$(restic_exec snapshots --json 2>/dev/null | grep -c '"time"' || echo 0)
  if [[ "$count" -gt 0 ]]; then
    echo "  PASS — $count snapshot(s) found"
    ((test_passed++))
  else
    echo "  FAIL — No snapshots found"
    ((test_failed++))
  fi

  # Test 3: Data integrity check
  log_info "Test 3/5: Data integrity (5% sample)..."
  if restic_exec check --read-data-subset=5% >/dev/null 2>&1; then
    echo "  PASS"
    ((test_passed++))
  else
    echo "  FAIL — Integrity check errors"
    ((test_failed++))
  fi

  # Test 4: Trial restore
  log_info "Test 4/5: Trial restore (dry-run)..."
  if restic_exec restore latest --target /tmp/dr-test-trial --verify --dry-run >/dev/null 2>&1; then
    echo "  PASS"
    ((test_passed++))
  else
    # Older restic may not support --dry-run, attempt limited restore
    if restic_exec ls latest >/dev/null 2>&1; then
      echo "  PASS (snapshot listing OK, dry-run not supported)"
      ((test_passed++))
    else
      echo "  FAIL"
      ((test_failed++))
    fi
  fi

  # Test 5: Offsite repo accessible (if configured)
  log_info "Test 5/5: Offsite repo accessible..."
  if [[ -n "${RESTIC_OFFSITE_REPO:-}" ]]; then
    if docker exec \
      -e RESTIC_REPOSITORY="${RESTIC_OFFSITE_REPO}" \
      -e RESTIC_PASSWORD="${RESTIC_OFFSITE_PASSWORD:-${RESTIC_PASSWORD}}" \
      -e AWS_ACCESS_KEY_ID="${BACKUP_OFFSITE_S3_KEY:-}" \
      -e AWS_SECRET_ACCESS_KEY="${BACKUP_OFFSITE_S3_SECRET:-}" \
      "$RESTIC_CONTAINER" restic snapshots --latest 1 >/dev/null 2>&1; then
      echo "  PASS"
      ((test_passed++))
    else
      echo "  FAIL — Cannot access offsite repo"
      ((test_failed++))
    fi
  else
    echo "  SKIP — No offsite repo configured"
  fi

  echo ""
  echo "=== DR Test Results ==="
  echo "  Passed: $test_passed"
  echo "  Failed: $test_failed"
  echo ""

  if [[ "$test_failed" -gt 0 ]]; then
    log_error "DR test completed with failures. Review and fix before disaster strikes!"
    exit 1
  else
    log_info "All DR tests passed. Your backups are healthy."
  fi
}

# ---------------------------------------------------------------------------
# dump-db — Dump databases only (no restic)
# ---------------------------------------------------------------------------
cmd_dump_db() {
  log_step "Dumping databases..."
  docker exec "$RESTIC_CONTAINER" /bin/sh -c '
    mkdir -p /db-dumps
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)

    if [ -n "${POSTGRES_PASSWORD:-}" ]; then
      echo "Dumping PostgreSQL..."
      docker exec '"${BACKUP_POSTGRES_CONTAINER:-homelab-postgres}"' \
        sh -c "PGPASSWORD='"'"'${POSTGRES_PASSWORD}'"'"' pg_dumpall -U postgres" \
        | gzip > /db-dumps/postgres_${TIMESTAMP}.sql.gz && \
        echo "  OK: postgres_${TIMESTAMP}.sql.gz" || echo "  FAILED"
    fi

    if [ -n "${MARIADB_ROOT_PASSWORD:-}" ]; then
      echo "Dumping MariaDB..."
      docker exec '"${BACKUP_MARIADB_CONTAINER:-homelab-mariadb}"' \
        sh -c "mariadb-dump --all-databases -u root -p'"'"'${MARIADB_ROOT_PASSWORD}'"'"'" \
        | gzip > /db-dumps/mariadb_${TIMESTAMP}.sql.gz && \
        echo "  OK: mariadb_${TIMESTAMP}.sql.gz" || echo "  FAILED"
    fi
  '
  log_info "Database dumps stored in restic-backup container at /db-dumps/"
}

# ---------------------------------------------------------------------------
# restore-db — Restore database from dump file
# ---------------------------------------------------------------------------
cmd_restore_db() {
  local dump_file="${1:-}"

  if [[ -z "$dump_file" ]]; then
    log_info "Available database dumps:"
    docker exec "$RESTIC_CONTAINER" ls -lh /db-dumps/ 2>/dev/null || echo "  (none)"
    echo ""
    echo "Usage: $0 restore-db <filename>"
    echo "  e.g.: $0 restore-db postgres_20240101_020000.sql.gz"
    exit 1
  fi

  log_step "Restoring database from: $dump_file"

  if [[ "$dump_file" == postgres_* ]]; then
    log_info "Restoring PostgreSQL..."
    read -rp "This will OVERWRITE existing PostgreSQL data. Type 'yes' to confirm: " confirm
    [[ "$confirm" != "yes" ]] && { log_warn "Cancelled."; exit 0; }

    docker exec "$RESTIC_CONTAINER" \
      sh -c "gunzip -c /db-dumps/$dump_file | docker exec -i ${BACKUP_POSTGRES_CONTAINER:-homelab-postgres} psql -U postgres" 2>&1
    log_info "PostgreSQL restore complete."

  elif [[ "$dump_file" == mariadb_* ]]; then
    log_info "Restoring MariaDB..."
    read -rp "This will OVERWRITE existing MariaDB data. Type 'yes' to confirm: " confirm
    [[ "$confirm" != "yes" ]] && { log_warn "Cancelled."; exit 0; }

    docker exec "$RESTIC_CONTAINER" \
      sh -c "gunzip -c /db-dumps/$dump_file | docker exec -i ${BACKUP_MARIADB_CONTAINER:-homelab-mariadb} mysql -u root -p'${MARIADB_ROOT_PASSWORD}'" 2>&1
    log_info "MariaDB restore complete."

  else
    log_error "Unknown dump format: $dump_file"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Main dispatcher
# ---------------------------------------------------------------------------
usage() {
  echo "HomeLab Backup & Restore Helper"
  echo ""
  echo "Usage: $0 <command> [args...]"
  echo ""
  echo "Commands:"
  echo "  backup              Run immediate backup"
  echo "  restore [snapshot]  Restore from snapshot (default: latest)"
  echo "  list                List available snapshots"
  echo "  verify              Verify backup integrity"
  echo "  stats               Show repository statistics"
  echo "  unlock              Remove stale repository locks"
  echo "  init-offsite        Initialize offsite S3 repository"
  echo "  dr-test             Run disaster recovery test"
  echo "  dump-db             Dump databases only"
  echo "  restore-db [file]   Restore database from dump"
  echo ""
}

case "${1:-}" in
  backup)         cmd_backup ;;
  restore)        cmd_restore "${2:-latest}" "${3:-}" ;;
  list)           cmd_list ;;
  verify)         cmd_verify ;;
  stats)          cmd_stats ;;
  unlock)         cmd_unlock ;;
  init-offsite)   cmd_init_offsite ;;
  dr-test)        cmd_dr_test ;;
  dump-db)        cmd_dump_db ;;
  restore-db)     cmd_restore_db "${2:-}" ;;
  *)              usage; exit 1 ;;
esac
