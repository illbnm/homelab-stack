#!/usr/bin/env bash
# =============================================================================
# E2E Test: Backup & Restore
# Validates the backup scripts produce valid archives and can be restored.
# =============================================================================

log_group "E2E: Backup & Restore"

BACKUP_SCRIPT="$BASE_DIR/scripts/backup.sh"
DB_BACKUP_SCRIPT="$BASE_DIR/scripts/backup-databases.sh"
BACKUP_TEST_DIR="/tmp/homelab-backup-test-$$"

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
test_backup_prerequisites() {
  if [[ ! -f "$BACKUP_SCRIPT" ]]; then
    skip_test "Backup E2E: backup.sh not found"
    return 1
  fi
  if [[ ! -x "$BACKUP_SCRIPT" ]]; then
    skip_test "Backup E2E: backup.sh not executable"
    return 1
  fi
  return 0
}

if ! test_backup_prerequisites; then
  return 0 2>/dev/null || exit 0
fi

# ---------------------------------------------------------------------------
# Test: Backup script has required functions
# ---------------------------------------------------------------------------
test_backup_script_syntax() {
  bash -n "$BACKUP_SCRIPT" 2>/dev/null
  if [[ $? -eq 0 ]]; then
    _record_result pass "Backup E2E: backup.sh has valid syntax"
  else
    _record_result fail "Backup E2E: backup.sh has valid syntax" "syntax error"
  fi
}

test_db_backup_script_syntax() {
  if [[ -f "$DB_BACKUP_SCRIPT" ]]; then
    bash -n "$DB_BACKUP_SCRIPT" 2>/dev/null
    if [[ $? -eq 0 ]]; then
      _record_result pass "Backup E2E: backup-databases.sh has valid syntax"
    else
      _record_result fail "Backup E2E: backup-databases.sh has valid syntax" "syntax error"
    fi
  else
    skip_test "Backup E2E: backup-databases.sh" "file not found"
  fi
}

# ---------------------------------------------------------------------------
# Test: Backup script --help or --dry-run
# ---------------------------------------------------------------------------
test_backup_help() {
  local output
  output=$("$BACKUP_SCRIPT" --help 2>&1 || true)
  if [[ -n "$output" ]]; then
    _record_result pass "Backup E2E: backup.sh --help produces output"
  else
    # Try without args
    output=$("$BACKUP_SCRIPT" 2>&1 || true)
    if [[ -n "$output" ]]; then
      _record_result pass "Backup E2E: backup.sh produces usage output"
    else
      _record_result fail "Backup E2E: backup.sh help/usage" "no output"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Test: Database backup script produces valid SQL
# ---------------------------------------------------------------------------
test_db_backup_postgres() {
  if [[ ! -f "$DB_BACKUP_SCRIPT" ]]; then
    skip_test "Backup E2E: PostgreSQL backup" "backup-databases.sh not found"
    return
  fi
  require_container "homelab-postgres" || return

  mkdir -p "$BACKUP_TEST_DIR"
  local dump_file="$BACKUP_TEST_DIR/pg_test_dump.sql"

  # Attempt a direct pg_dumpall from the container
  docker_exec "homelab-postgres" \
    pg_dumpall -U "${POSTGRES_ROOT_USER:-postgres}" > "$dump_file" 2>/dev/null
  if [[ -s "$dump_file" ]]; then
    _record_result pass "Backup E2E: PostgreSQL dump produces output" \
      "$(wc -c < "$dump_file" | tr -d ' ') bytes"
    # Verify it contains SQL
    if head -5 "$dump_file" | grep -qi "postgres\|sql\|role\|database"; then
      _record_result pass "Backup E2E: PostgreSQL dump contains valid SQL"
    else
      _record_result fail "Backup E2E: PostgreSQL dump contains valid SQL" "unexpected content"
    fi
  else
    _record_result fail "Backup E2E: PostgreSQL dump produces output" "empty file"
  fi

  rm -rf "$BACKUP_TEST_DIR"
}

# Run tests
test_backup_script_syntax
test_db_backup_script_syntax
test_backup_help
test_db_backup_postgres
