#!/usr/bin/env bash
# =============================================================================
# HomeLab — Backup & Restore E2E Test
# =============================================================================
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib"; pwd)"
source "$_LIB_DIR/assert.sh"

BACKUP_SCRIPT="$BASE_DIR/scripts/backup.sh"

test_backup_script_exists() {
  assert_file_exists "$BACKUP_SCRIPT" "backup.sh should exist"
}

test_backup_script_executable() {
  [[ -x "$BACKUP_SCRIPT" ]]
  _assert_result $? "backup.sh should be executable"
}

test_backup_dry_run() {
  if [[ ! -f "$BACKUP_SCRIPT" ]]; then
    echo "backup.sh not found, skipping"
    return 0
  fi
  local output
  output=$("$BACKUP_SCRIPT" --target all --dry-run 2>&1)
  assert_contains "$output" "DRY-RUN" "Dry run should mention DRY-RUN"
}

test_backup_list() {
  if [[ ! -f "$BACKUP_SCRIPT" ]]; then
    echo "backup.sh not found, skipping"
    return 0
  fi
  local output
  output=$("$BACKUP_SCRIPT" --list 2>&1)
  # Should not error out
  assert_exit_code $? 0 "backup.sh --list should exit 0"
}

test_backup_notify_script_exists() {
  assert_file_exists "$BASE_DIR/scripts/backup-notify.sh" "backup-notify.sh should exist"
}

test_backup_schedule_script_exists() {
  assert_file_exists "$BASE_DIR/scripts/backup-schedule.sh" "backup-schedule.sh should exist"
}

test_disaster_recovery_docs() {
  assert_file_exists "$BASE_DIR/docs/disaster-recovery.md" "disaster-recovery.md should exist"
}

test_disaster_recovery_has_rto() {
  assert_file_contains "$BASE_DIR/docs/disaster-recovery.md" "RTO" "DR docs should mention RTO"
}

test_backup_compose_exists() {
  assert_file_exists "$BASE_DIR/stacks/backup/docker-compose.yml" "backup compose should exist"
}

test_backup_compose_no_latest() {
  assert_no_latest_images "$BASE_DIR/stacks/backup" "Backup stack should pin image versions"
}
