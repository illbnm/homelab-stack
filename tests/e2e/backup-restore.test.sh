#!/usr/bin/env bash
# backup-restore.test.sh — Backup/Restore End-to-End Tests
set -euo pipefail

test_backup_script_exists() {
  test_start "Backup script exists"
  if [[ -f "scripts/backup.sh" ]]; then
    test_pass "scripts/backup.sh exists"
  else
    test_fail "scripts/backup.sh not found"
  fi
  test_end
}

test_backup_databases_script_exists() {
  test_start "Database backup script exists"
  if [[ -f "scripts/backup-databases.sh" ]]; then
    test_pass "scripts/backup-databases.sh exists"
  else
    test_fail "scripts/backup-databases.sh not found"
  fi
  test_end
}

test_backup_script_syntax() {
  test_start "Backup script syntax valid"
  bash -n scripts/backup.sh 2>/dev/null
  local rc=$?
  if [[ "$rc" -eq 0 ]]; then
    test_pass "scripts/backup.sh syntax OK"
  else
    test_fail "scripts/backup.sh syntax error"
  fi
  test_end
}

test_backup_databases_script_syntax() {
  test_start "Database backup script syntax valid"
  bash -n scripts/backup-databases.sh 2>/dev/null
  local rc=$?
  if [[ "$rc" -eq 0 ]]; then
    test_pass "scripts/backup-databases.sh syntax OK"
  else
    test_fail "scripts/backup-databases.sh syntax error"
  fi
  test_end
}
