#!/usr/bin/env bash
# =============================================================================
# E2E Test — Backup & Restore
#
# Tests the backup script produces valid archives and that critical data
# can be verified inside the backup.
#
# Requires: databases stack running, backup script at scripts/backup-databases.sh
# =============================================================================

BACKUP_SCRIPT="stacks/databases/scripts/backup-databases.sh"
TEST_BACKUP_DIR="/tmp/homelab-test-backup"

_check_backup_prereqs() {
  if [[ ! -f "${BACKUP_SCRIPT}" ]]; then
    return 1
  fi
  if ! docker inspect --format='{{.State.Running}}' homelab-postgres > /dev/null 2>&1; then
    return 1
  fi
  return 0
}

test_e2e_backup_script_exists() {
  if [[ -f "${BACKUP_SCRIPT}" ]]; then
    _pass
  else
    _fail "Backup script not found at ${BACKUP_SCRIPT}"
  fi
}

test_e2e_backup_script_executable() {
  if [[ -x "${BACKUP_SCRIPT}" ]]; then
    _pass
  else
    _fail "Backup script is not executable"
  fi
}

test_e2e_backup_creates_archive() {
  if ! _check_backup_prereqs; then
    _skip "Prerequisites not met (databases not running or script missing)"
    return
  fi

  # Clean up test dir
  rm -rf "${TEST_BACKUP_DIR}"
  mkdir -p "${TEST_BACKUP_DIR}"

  # Run backup
  BACKUP_DIR="${TEST_BACKUP_DIR}" "${BACKUP_SCRIPT}" > /dev/null 2>&1
  local exit_code=$?

  # Check that at least one archive was created
  local archive_count
  archive_count=$(find "${TEST_BACKUP_DIR}" -name "homelab-db-backup-*.tar.gz" 2>/dev/null | wc -l | tr -d ' ')

  if [[ "${archive_count}" -gt 0 && "${exit_code}" -eq 0 ]]; then
    _pass
  else
    _fail "Backup produced ${archive_count} archive(s), exit code ${exit_code}"
  fi

  # Clean up
  rm -rf "${TEST_BACKUP_DIR}"
}

test_e2e_backup_contains_postgres() {
  if ! _check_backup_prereqs; then
    _skip "Prerequisites not met"
    return
  fi

  rm -rf "${TEST_BACKUP_DIR}"
  mkdir -p "${TEST_BACKUP_DIR}"

  BACKUP_DIR="${TEST_BACKUP_DIR}" "${BACKUP_SCRIPT}" > /dev/null 2>&1

  local archive
  archive=$(find "${TEST_BACKUP_DIR}" -name "homelab-db-backup-*.tar.gz" 2>/dev/null | sort | tail -1)

  if [[ -z "${archive}" ]]; then
    _fail "No backup archive found"
    rm -rf "${TEST_BACKUP_DIR}"
    return
  fi

  # Check archive contains postgres dump
  if tar tzf "${archive}" 2>/dev/null | grep -q "postgres"; then
    _pass
  else
    _fail "Backup archive does not contain PostgreSQL dump"
  fi

  rm -rf "${TEST_BACKUP_DIR}"
}

test_e2e_backup_contains_redis() {
  if ! _check_backup_prereqs; then
    _skip "Prerequisites not met"
    return
  fi

  rm -rf "${TEST_BACKUP_DIR}"
  mkdir -p "${TEST_BACKUP_DIR}"

  BACKUP_DIR="${TEST_BACKUP_DIR}" "${BACKUP_SCRIPT}" > /dev/null 2>&1

  local archive
  archive=$(find "${TEST_BACKUP_DIR}" -name "homelab-db-backup-*.tar.gz" 2>/dev/null | sort | tail -1)

  if [[ -z "${archive}" ]]; then
    _fail "No backup archive found"
    rm -rf "${TEST_BACKUP_DIR}"
    return
  fi

  if tar tzf "${archive}" 2>/dev/null | grep -q "redis"; then
    _pass
  else
    _fail "Backup archive does not contain Redis dump"
  fi

  rm -rf "${TEST_BACKUP_DIR}"
}
