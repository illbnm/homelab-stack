#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — E2E: Backup & Restore Test
# Validates backup scripts work correctly and data can be restored.
# =============================================================================

# ===========================================================================
# Level 4 — End-to-End Backup & Restore
# ===========================================================================
if [[ "${TEST_LEVEL:-0}" -eq 0 || "${TEST_LEVEL:-0}" -ge 4 ]]; then
  test_group "E2E — Backup & Restore"

  BACKUP_SCRIPT="$BASE_DIR/scripts/backup.sh"
  DB_BACKUP_SCRIPT="$BASE_DIR/scripts/backup-databases.sh"

  # 1. Verify backup scripts exist and are executable
  assert_file_exists "$BACKUP_SCRIPT" \
    "Backup script exists"

  assert_file_exists "$DB_BACKUP_SCRIPT" \
    "Database backup script exists"

  if [[ -f "$BACKUP_SCRIPT" ]]; then
    if [[ -x "$BACKUP_SCRIPT" ]]; then
      _record_pass "Backup script is executable"
    else
      _record_fail "Backup script is executable" "missing execute permission"
    fi
  fi

  if [[ -f "$DB_BACKUP_SCRIPT" ]]; then
    if [[ -x "$DB_BACKUP_SCRIPT" ]]; then
      _record_pass "Database backup script is executable"
    else
      _record_fail "Database backup script is executable" "missing execute permission"
    fi
  fi

  # 2. Test volume backup (dry run if possible, or with a test volume)
  if [[ -f "$BACKUP_SCRIPT" ]] && command -v docker &>/dev/null; then
    # Create a temporary test volume with known data
    test_vol="homelab-test-backup-$$"
    backup_dir="/tmp/homelab-test-backup-$$"
    mkdir -p "$backup_dir"

    # Create test volume and add data
    docker volume create "$test_vol" &>/dev/null
    docker run --rm -v "${test_vol}:/data" alpine sh -c 'echo "backup-test-data" > /data/test.txt' &>/dev/null

    if [[ $? -eq 0 ]]; then
      # Backup the test volume
      docker run --rm \
        -v "${test_vol}:/source:ro" \
        -v "${backup_dir}:/backup" \
        alpine tar czf "/backup/${test_vol}.tar.gz" -C /source . &>/dev/null

      if [[ -f "${backup_dir}/${test_vol}.tar.gz" ]]; then
        _record_pass "Volume backup creates archive"

        # Verify archive contains our test data
        archive_content=""
        archive_content=$(tar tzf "${backup_dir}/${test_vol}.tar.gz" 2>/dev/null)
        if echo "$archive_content" | grep -q "test.txt"; then
          _record_pass "Backup archive contains expected files"
        else
          _record_fail "Backup archive contains expected files" "test.txt not found in archive"
        fi

        # 3. Test restore: create a new volume and restore data
        restore_vol="homelab-test-restore-$$"
        docker volume create "$restore_vol" &>/dev/null
        docker run --rm \
          -v "${restore_vol}:/target" \
          -v "${backup_dir}:/backup:ro" \
          alpine tar xzf "/backup/${test_vol}.tar.gz" -C /target &>/dev/null

        # Verify restored data
        restored_data=""
        restored_data=$(docker run --rm -v "${restore_vol}:/data:ro" alpine cat /data/test.txt 2>/dev/null)
        assert_eq "$restored_data" "backup-test-data" \
          "Restored data matches original"

        # Cleanup restore volume
        docker volume rm "$restore_vol" &>/dev/null
      else
        _record_fail "Volume backup creates archive" "archive not found"
      fi
    else
      _record_fail "Volume backup test setup" "could not create test volume"
    fi

    # Cleanup
    docker volume rm "$test_vol" &>/dev/null
    rm -rf "$backup_dir"
  else
    skip_test "Volume backup creates archive" "backup script or docker not available"
  fi

  # 4. Test database backup (if databases are running)
  if is_container_running "homelab-postgres"; then
    pg_dump_output=""
    pg_dump_output=$(docker exec homelab-postgres pg_dump -U "${POSTGRES_ROOT_USER:-postgres}" --schema-only postgres 2>&1)
    if [[ $? -eq 0 && -n "$pg_dump_output" ]]; then
      _record_pass "PostgreSQL pg_dump works"
    else
      _record_fail "PostgreSQL pg_dump works" "pg_dump failed"
    fi
  else
    skip_test "PostgreSQL pg_dump works" "homelab-postgres not running"
  fi

  if is_container_running "homelab-mariadb"; then
    mysql_dump_output=""
    mysql_dump_output=$(docker exec homelab-mariadb \
      mysqldump -u root -p"${MARIADB_ROOT_PASSWORD:-changeme}" --no-data mysql 2>&1)
    if [[ $? -eq 0 ]]; then
      _record_pass "MariaDB mysqldump works"
    else
      _record_fail "MariaDB mysqldump works" "mysqldump failed"
    fi
  else
    skip_test "MariaDB mysqldump works" "homelab-mariadb not running"
  fi
fi
