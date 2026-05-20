#!/usr/bin/env bash

run_backup_restore_tests() {
  CURRENT_SUITE="backup-restore"
  assert_file_executable "$PROJECT_ROOT/scripts/backup.sh" "Full backup script is executable"
  assert_file_executable "$PROJECT_ROOT/scripts/backup-databases.sh" "Database backup script is executable"
  assert_file_contains "$PROJECT_ROOT/scripts/backup.sh" 'backup_configs' "Full backup includes configuration files"
  assert_file_contains "$PROJECT_ROOT/scripts/backup.sh" 'backup_volumes' "Full backup includes Docker volumes"
  assert_file_contains "$PROJECT_ROOT/scripts/backup.sh" 'backup_databases' "Full backup includes databases"
  assert_file_contains "$PROJECT_ROOT/scripts/backup-databases.sh" 'backup_postgres' "Database backup includes PostgreSQL"
  assert_file_contains "$PROJECT_ROOT/scripts/backup-databases.sh" 'backup_redis' "Database backup includes Redis"
  assert_file_contains "$PROJECT_ROOT/scripts/backup-databases.sh" 'backup_mariadb' "Database backup includes MariaDB"

  assert_container_running homelab-postgres "PostgreSQL is running before backup E2E"
  assert_container_running homelab-redis "Redis is running before backup E2E"
  assert_container_running homelab-mariadb "MariaDB is running before backup E2E"

  if ! docker_available; then
    skip_result "Database backup E2E command runs" "docker is not available"
    return
  fi
  if ! docker ps --format '{{.Names}}' | grep -Fxq homelab-postgres || \
     ! docker ps --format '{{.Names}}' | grep -Fxq homelab-redis || \
     ! docker ps --format '{{.Names}}' | grep -Fxq homelab-mariadb; then
    skip_result "Database backup E2E command runs" "database containers are not all running"
    return
  fi

  local backup_dir start_ms output exit_code
  backup_dir="$PROJECT_ROOT/tests/results/backup-e2e"
  mkdir -p "$backup_dir"
  start_ms=$(current_millis)
  set +e
  output=$(BACKUP_DIR="$backup_dir" "$PROJECT_ROOT/scripts/backup-databases.sh" --all 2>&1)
  exit_code=$?
  set -e
  assert_exit_code 0 "$exit_code" "Database backup E2E exits successfully"
  if [[ "$exit_code" -eq 0 ]]; then
    assert_no_errors "$output" "Database backup E2E output has no fatal errors"
    if grep -q 'All backups completed' <<< "$output"; then
      pass_result "Database backup E2E reports completion" "$output" "$start_ms"
    else
      fail_result "Database backup E2E reports completion" "$output" "$start_ms"
    fi
  else
    fail_result "Database backup E2E command output" "$output" "$start_ms"
  fi
}
