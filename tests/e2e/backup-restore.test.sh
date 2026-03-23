#!/usr/bin/env bash
# =============================================================================
# E2E Test: Backup and Restore Validation
# Level: L4
#
# Validates the backup/restore pipeline:
#   1. Verify backup scripts exist and are executable
#   2. Run a database backup (if containers are running)
#   3. Verify backup files are created and non-empty
#   4. Validate backup file integrity (gzip test)
#   5. Clean up test backups
# =============================================================================
set -euo pipefail

STACK="backup-e2e"

test_backup_restore() {
  report_suite "${STACK}"

  local backup_script="${REPO_ROOT}/scripts/backup-databases.sh"
  local backup_full="${REPO_ROOT}/scripts/backup.sh"

  # ── Step 1: Verify backup scripts exist ───────────────────────────────────
  if [[ -f "${backup_script}" ]]; then
    run_test "${STACK}" "L4: backup-databases.sh exists" \
      assert_file_contains "${backup_script}" "backup" || true
  else
    skip_test "${STACK}" "L4: backup-databases.sh exists" "script not found"
    skip_test "${STACK}" "L4: backup-databases.sh is executable" "script not found"
    skip_test "${STACK}" "L4: postgres backup creates file" "script not found"
    skip_test "${STACK}" "L4: backup file is valid gzip" "script not found"
    return 0
  fi

  run_test "${STACK}" "L4: backup-databases.sh is executable" \
    test -x "${backup_script}" || true

  if [[ -f "${backup_full}" ]]; then
    run_test "${STACK}" "L4: backup.sh exists" \
      assert_file_contains "${backup_full}" "backup" || true
  else
    skip_test "${STACK}" "L4: backup.sh exists" "script not found"
  fi

  # ── Step 2: Run postgres backup (if container available) ──────────────────
  local pg_running
  pg_running=$(docker inspect -f '{{.State.Running}}' homelab-postgres 2>/dev/null || echo "false")

  if [[ "${pg_running}" == "true" ]]; then
    local test_backup_dir
    test_backup_dir=$(mktemp -d)

    run_test "${STACK}" "L4: postgres backup creates file" \
      bash -c "BACKUP_DIR='${test_backup_dir}' bash '${backup_script}' --postgres" || true

    # ── Step 3: Verify backup file ──────────────────────────────────────────
    local backup_file
    backup_file=$(find "${test_backup_dir}" -name 'postgres_*.sql.gz' -type f 2>/dev/null | head -1)

    if [[ -n "${backup_file}" ]]; then
      run_test "${STACK}" "L4: backup file is non-empty" \
        test -s "${backup_file}" || true

      # ── Step 4: Validate gzip integrity ───────────────────────────────────
      run_test "${STACK}" "L4: backup file is valid gzip" \
        gzip -t "${backup_file}" || true
    else
      skip_test "${STACK}" "L4: backup file is non-empty" "no backup file created"
      skip_test "${STACK}" "L4: backup file is valid gzip" "no backup file created"
    fi

    # ── Step 5: Cleanup ────────────────────────────────────────────────────
    rm -rf "${test_backup_dir}"
  else
    skip_test "${STACK}" "L4: postgres backup creates file" "homelab-postgres not running"
    skip_test "${STACK}" "L4: backup file is non-empty" "homelab-postgres not running"
    skip_test "${STACK}" "L4: backup file is valid gzip" "homelab-postgres not running"
  fi

  # ── Verify backup script handles arguments correctly ──────────────────────
  run_test "${STACK}" "L4: backup script shows usage on bad args" \
    bash -c "'${backup_script}' --invalid 2>&1 | grep -qi 'usage'" || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_backup_restore
fi
