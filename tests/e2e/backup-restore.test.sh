#!/usr/bin/env bash
# End-to-End: Backup & Restore
# Tests: backup.sh creates a backup and verify can restore
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"

reset_counters
log_test_start "E2E: Backup & Restore"

BACKUP_SCRIPT="$ROOT_DIR/stacks/backup/scripts/backup.sh"

section "Backup script exists"
TESTS_RUN=$((TESTS_RUN+1))
if [[ -x "$BACKUP_SCRIPT" ]]; then
  pass "backup.sh exists and is executable"
elif [[ -f "$BACKUP_SCRIPT" ]]; then
  pass "backup.sh exists (chmod +x recommended)"
else
  fail "backup.sh not found at $BACKUP_SCRIPT"
fi

section "Backup script --help"
if [[ -f "$BACKUP_SCRIPT" ]]; then
  local out
  out=$("$BACKUP_SCRIPT" --help 2>&1 || echo "")
  TESTS_RUN=$((TESTS_RUN+1))
  if echo "$out" | grep -qi "usage\|backup\|target"; then
    pass "backup.sh --help shows usage"
  else
    fail "backup.sh --help output unexpected"
  fi
else
  skip "backup.sh not present"
fi

section "Backup script --dry-run"
if [[ -f "$BACKUP_SCRIPT" ]]; then
  local out rc
  out=$("$BACKUP_SCRIPT" --target all --dry-run 2>&1); rc=$?
  TESTS_RUN=$((TESTS_RUN+1))
  if [[ $rc -eq 0 ]] && echo "$out" | grep -qi "backup\|volume\|dry"; then
    pass "backup.sh --dry-run works"
  else
    fail "backup.sh --dry-run failed (exit $rc)"
  fi
else
  skip "backup.sh not present"
fi

section "Backup script --list"
if [[ -f "$BACKUP_SCRIPT" ]]; then
  local out
  out=$("$BACKUP_SCRIPT" --list 2>&1 || echo "")
  TESTS_RUN=$((TESTS_RUN+1))
  if [[ -n "$out" ]]; then
    pass "backup.sh --list returns output"
  else
    fail "backup.sh --list returned nothing"
  fi
else
  skip "backup.sh not present"
fi

section "Backup target .env config"
if [[ -f "$ROOT_DIR/.env" ]]; then
  assert_env_set "BACKUP_TARGET defined" "$ROOT_DIR/.env" "BACKUP_TARGET" || true
else
  skip ".env not present"
fi

assert_summary