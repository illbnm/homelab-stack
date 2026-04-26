#!/usr/bin/env bash
# =============================================================================
# HomeLab Backup & Restore Helper
# Usage: ./backup-restore.sh <command> [args...]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
STACK_DIR="$ROOT_DIR/stacks/backup"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[backup]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[backup]${NC} $*"; }
log_error() { echo -e "${RED}[backup]${NC} $*" >&2; }
log_step()  { echo -e "${CYAN}[step]${NC} ${BOLD}$*${NC}"; }

[[ -f "$ROOT_DIR/.env" ]] && { set -a; source "$ROOT_DIR/.env"; set +a; }

RESTIC_CONTAINER="${RESTIC_CONTAINER:-restic-backup}"

restic_exec() { docker exec "$RESTIC_CONTAINER" restic "$@"; }

cmd_backup() {
  log_step "Triggering immediate backup..."
  docker exec "$RESTIC_CONTAINER" /usr/local/bin/backup.sh
  log_info "Backup completed. Use '$0 list' to see snapshots."
}

cmd_list() {
  log_step "Available snapshots:"
  restic_exec snapshots --compact
}

cmd_restore() {
  local snapshot="${1:-latest}"
  local target="${2:-/tmp/restic-restore}"
  log_step "Restore plan: snapshot=$snapshot target=$target"
  restic_exec ls "$snapshot" --long 2>/dev/null | head -30
  echo ""
  read -rp "Proceed with restore? (yes/no): " confirm
  [[ "$confirm" != "yes" ]] && { log_warn "Cancelled."; exit 0; }

  mkdir -p "$target"

  echo "Running containers:"
  docker ps --format '  - {{.Names}} ({{.Status}})' | head -20
  read -rp "Stop any containers? (comma-separated, or ENTER to skip): " stop_list
  if [[ -n "$stop_list" ]]; then
    IFS=',' read -ra containers <<< "$stop_list"
    for c in "${containers[@]}"; do
      c=$(echo "$c" | xargs)
      docker stop "$c" 2>/dev/null || log_warn "Could not stop $c"
    done
  fi

  log_step "Restoring..."
  docker exec "$RESTIC_CONTAINER" restic restore "$snapshot" --target /restore-target --verbose 2>&1 | tail -20
  docker cp "${RESTIC_CONTAINER}:/restore-target/." "$target/"

  local restored_size; restored_size=$(du -sh "$target" 2>/dev/null | cut -f1)
  log_info "Restored $restored_size to $target"

  if [[ -n "${stop_list:-}" ]]; then
    read -rp "Restart stopped containers? (yes/no): " restart_yn
    if [[ "$restart_yn" == "yes" ]]; then
      for c in "${containers[@]}"; do
        c=$(echo "$c" | xargs); docker start "$c" 2>/dev/null || true
      done
    fi
  fi
  log_info "Restore complete! Files in: $target"
}

cmd_verify() {
  log_step "Verifying backup integrity..."
  log_info "Phase 1: Repository structure..."
  restic_exec check 2>&1
  log_info "Phase 2: Data integrity (10% sample)..."
  restic_exec check --read-data-subset=10% 2>&1
  log_info "Phase 3: Latest snapshots..."
  restic_exec snapshots --latest 3
  log_info "Verification complete."
}

cmd_stats() {
  log_step "Repository statistics:"
  restic_exec stats
  restic_exec snapshots --compact
}

cmd_unlock() {
  log_step "Removing stale locks..."
  restic_exec unlock --remove-all 2>&1
  log_info "Locks removed."
}

cmd_init_offsite() {
  [[ -z "${RESTIC_OFFSITE_REPO:-}" ]] && {
    log_error "RESTIC_OFFSITE_REPO not set. Configure in .env."
    echo "  Examples:"
    echo "  RESTIC_OFFSITE_REPO=s3:s3.amazonaws.com/your-bucket"
    echo "  RESTIC_OFFSITE_REPO=s3:s3.us-west-004.backblazeb2.com/your-bucket"
    echo "  RESTIC_OFFSITE_REPO=s3:s3.wasabisys.com/your-bucket"
    exit 1
  }
  log_step "Initializing offsite: ${RESTIC_OFFSITE_REPO}"
  docker exec \
    -e RESTIC_REPOSITORY="${RESTIC_OFFSITE_REPO}" \
    -e RESTIC_PASSWORD="${RESTIC_OFFSITE_PASSWORD:-${RESTIC_PASSWORD}}" \
    -e AWS_ACCESS_KEY_ID="${BACKUP_OFFSITE_S3_KEY:-}" \
    -e AWS_SECRET_ACCESS_KEY="${BACKUP_OFFSITE_S3_SECRET:-}" \
    "$RESTIC_CONTAINER" restic init 2>&1
  log_info "Offsite repo initialized."
}

cmd_dr_test() {
  log_step "=== Disaster Recovery Test ==="
  echo "Validates backup chain WITHOUT modifying production data."
  local pass=0 fail=0

  log_info "Test 1/5: Repository accessible..."
  if restic_exec snapshots --latest 1 >/dev/null 2>&1; then echo "  PASS"; ((pass++))
  else echo "  FAIL"; ((fail++)); fi

  log_info "Test 2/5: Snapshots exist..."
  local count; count=$(restic_exec snapshots --json 2>/dev/null | grep -c '"time"' || echo 0)
  if [[ "$count" -gt 0 ]]; then echo "  PASS ($count snapshots)"; ((pass++))
  else echo "  FAIL"; ((fail++)); fi

  log_info "Test 3/5: Data integrity (5%)..."
  if restic_exec check --read-data-subset=5% >/dev/null 2>&1; then echo "  PASS"; ((pass++))
  else echo "  FAIL"; ((fail++)); fi

  log_info "Test 4/5: Snapshot listing..."
  if restic_exec ls latest >/dev/null 2>&1; then echo "  PASS"; ((pass++))
  else echo "  FAIL"; ((fail++)); fi

  log_info "Test 5/5: Offsite repo..."
  if [[ -n "${RESTIC_OFFSITE_REPO:-}" ]]; then
    if docker exec \
      -e RESTIC_REPOSITORY="${RESTIC_OFFSITE_REPO}" \
      -e RESTIC_PASSWORD="${RESTIC_OFFSITE_PASSWORD:-${RESTIC_PASSWORD}}" \
      -e AWS_ACCESS_KEY_ID="${BACKUP_OFFSITE_S3_KEY:-}" \
      -e AWS_SECRET_ACCESS_KEY="${BACKUP_OFFSITE_S3_SECRET:-}" \
      "$RESTIC_CONTAINER" restic snapshots --latest 1 >/dev/null 2>&1; then
      echo "  PASS"; ((pass++))
    else echo "  FAIL"; ((fail++)); fi
  else echo "  SKIP (not configured)"; fi

  echo ""
  echo "Results: $pass passed, $fail failed"
  [[ "$fail" -gt 0 ]] && { log_error "DR test has failures!"; exit 1; }
  log_info "All DR tests passed."
}

cmd_dump_db() {
  log_step "Dumping databases..."
  docker exec "$RESTIC_CONTAINER" /usr/local/bin/backup.sh
  log_info "Done. Dumps in container at /db-dumps/"
}

cmd_restore_db() {
  local dump_file="${1:-}"
  if [[ -z "$dump_file" ]]; then
    log_info "Available dumps:"
    docker exec "$RESTIC_CONTAINER" ls -lh /db-dumps/ 2>/dev/null || echo "  (none)"
    echo "Usage: $0 restore-db <filename>"
    exit 1
  fi

  log_step "Restoring: $dump_file"
  if [[ "$dump_file" == postgres_* ]]; then
    read -rp "OVERWRITE PostgreSQL data? Type 'yes': " confirm
    [[ "$confirm" != "yes" ]] && exit 0
    docker exec "$RESTIC_CONTAINER" sh -c "gunzip -c /db-dumps/$dump_file | docker exec -i ${BACKUP_POSTGRES_CONTAINER:-homelab-postgres} psql -U postgres"
    log_info "PostgreSQL restored."
  elif [[ "$dump_file" == mariadb_* ]]; then
    read -rp "OVERWRITE MariaDB data? Type 'yes': " confirm
    [[ "$confirm" != "yes" ]] && exit 0
    docker exec "$RESTIC_CONTAINER" sh -c "gunzip -c /db-dumps/$dump_file | docker exec -i ${BACKUP_MARIADB_CONTAINER:-homelab-mariadb} mysql -u root -p'${MARIADB_ROOT_PASSWORD}'"
    log_info "MariaDB restored."
  else
    log_error "Unknown format: $dump_file"; exit 1
  fi
}

usage() {
  echo "HomeLab Backup & Restore Helper"
  echo ""
  echo "Usage: $0 <command> [args...]"
  echo ""
  echo "Commands:"
  echo "  backup              Run immediate backup"
  echo "  restore [snapshot]  Restore (default: latest)"
  echo "  list                List snapshots"
  echo "  verify              Verify integrity"
  echo "  stats               Repository statistics"
  echo "  unlock              Remove stale locks"
  echo "  init-offsite        Initialize offsite S3 repo"
  echo "  dr-test             Disaster recovery test"
  echo "  dump-db             Dump databases"
  echo "  restore-db [file]   Restore database"
}

case "${1:-}" in
  backup)       cmd_backup ;;
  restore)      cmd_restore "${2:-latest}" "${3:-}" ;;
  list)         cmd_list ;;
  verify)       cmd_verify ;;
  stats)        cmd_stats ;;
  unlock)       cmd_unlock ;;
  init-offsite) cmd_init_offsite ;;
  dr-test)      cmd_dr_test ;;
  dump-db)      cmd_dump_db ;;
  restore-db)   cmd_restore_db "${2:-}" ;;
  *)            usage; exit 1 ;;
esac
