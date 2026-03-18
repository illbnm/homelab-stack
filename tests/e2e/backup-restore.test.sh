# E2E: Backup & Restore Test

echo "--- Backup & Restore Flow ---"

CURRENT_TEST="backup_script_exists"
if [[ -x "scripts/backup.sh" ]]; then
  pass
else
  fail_test "scripts/backup.sh not found or not executable"
  return
fi

CURRENT_TEST="backup_dry_run"
local dry_output=$(bash scripts/backup.sh --target all --dry-run 2>&1)
assert_contains "$dry_output" "DRY-RUN" "Dry run mode works"

CURRENT_TEST="backup_list"
local list_output=$(bash scripts/backup.sh --list 2>&1)
assert_not_empty "$list_output" "List command works"

CURRENT_TEST="backup_databases_script"
if [[ -x "scripts/backup-databases.sh" ]]; then
  pass
else
  skip "backup-databases.sh not found"
fi

CURRENT_TEST="backup_verify"
# Only run if backups exist
if ls backups/backup-*.tar.gz 1>/dev/null 2>&1; then
  local verify_output=$(bash scripts/backup.sh --verify 2>&1)
  assert_contains "$verify_output" "Verified" "Backup verification works"
else
  skip "No backups to verify"
fi
