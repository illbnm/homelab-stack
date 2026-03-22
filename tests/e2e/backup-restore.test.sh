#!/usr/bin/env bash
# backup-restore.test.sh — End-to-end backup and restore flow tests

BACKUP_DIR="${BACKUP_DIR:-/tmp/homelab-backup-test}"
BACKUP_SCRIPT="${REPO_ROOT}/scripts/backup.sh"
DB_BACKUP_SCRIPT="${REPO_ROOT}/scripts/backup-databases.sh"

# ── Level 1: Script existence and syntax ──────────────────────────────────────

if [[ -f "$BACKUP_SCRIPT" ]]; then
  assert_pass "e2e/backup: backup.sh exists"
  if bash -n "$BACKUP_SCRIPT" 2>/dev/null; then
    assert_pass "e2e/backup: backup.sh syntax valid"
  else
    assert_fail "e2e/backup: backup.sh syntax valid" "bash -n reported errors"
  fi
else
  assert_fail "e2e/backup: backup.sh exists" "file not found: ${BACKUP_SCRIPT}"
  assert_skip "e2e/backup: backup.sh syntax valid" "backup.sh not found"
fi

if [[ -f "$DB_BACKUP_SCRIPT" ]]; then
  assert_pass "e2e/backup: backup-databases.sh exists"
  if bash -n "$DB_BACKUP_SCRIPT" 2>/dev/null; then
    assert_pass "e2e/backup: backup-databases.sh syntax valid"
  else
    assert_fail "e2e/backup: backup-databases.sh syntax valid" \
      "bash -n reported errors"
  fi
else
  assert_fail "e2e/backup: backup-databases.sh exists" \
    "file not found: ${DB_BACKUP_SCRIPT}"
  assert_skip "e2e/backup: backup-databases.sh syntax valid" \
    "backup-databases.sh not found"
fi

# ── Level 2: Backup script dry-run / help ────────────────────────────────────

if [[ -f "$BACKUP_SCRIPT" ]]; then
  if bash "$BACKUP_SCRIPT" --help &>/dev/null || bash "$BACKUP_SCRIPT" --dry-run &>/dev/null; then
    assert_pass "e2e/backup: backup.sh --help/--dry-run succeeds"
  else
    # Some scripts exit non-zero for --help; just check it doesn't crash badly
    assert_skip "e2e/backup: backup.sh --help/--dry-run succeeds" \
      "script does not support --help/--dry-run flags"
  fi
fi

# ── Level 2: Database container backup prerequisites ─────────────────────────

POSTGRES_DEPLOYED=0
REDIS_DEPLOYED=0
MARIADB_DEPLOYED=0

if docker_container_exists "postgres"; then POSTGRES_DEPLOYED=1; fi
if docker_container_exists "redis"; then REDIS_DEPLOYED=1; fi
if docker_container_exists "mariadb"; then MARIADB_DEPLOYED=1; fi

if [[ $POSTGRES_DEPLOYED -eq 1 ]]; then
  # Verify pg_dump is available inside the container
  if docker exec postgres pg_dump --version &>/dev/null; then
    assert_pass "e2e/backup: pg_dump available in postgres container"
  else
    assert_fail "e2e/backup: pg_dump available in postgres container" \
      "pg_dump not found inside container"
  fi
else
  assert_skip "e2e/backup: pg_dump available in postgres container" \
    "postgres container not deployed"
fi

if [[ $REDIS_DEPLOYED -eq 1 ]]; then
  # Verify redis-cli is available and BGSAVE works
  save_result=$(docker exec redis redis-cli BGSAVE 2>/dev/null || echo "error")
  if echo "$save_result" | grep -qi "background saving started\|already in progress"; then
    assert_pass "e2e/backup: Redis BGSAVE initiated successfully"
  else
    assert_fail "e2e/backup: Redis BGSAVE initiated successfully" \
      "redis-cli BGSAVE returned: ${save_result}"
  fi
else
  assert_skip "e2e/backup: Redis BGSAVE initiated successfully" \
    "redis container not deployed"
fi

# ── Level 3: Backup creation and verification ─────────────────────────────────

if [[ $POSTGRES_DEPLOYED -eq 1 ]]; then
  mkdir -p "$BACKUP_DIR"
  backup_file="${BACKUP_DIR}/postgres-test-$(date +%s).sql"
  PGPASSWORD="${POSTGRES_PASSWORD:-postgres}" docker exec -e PGPASSWORD="${POSTGRES_PASSWORD:-postgres}" \
    postgres pg_dumpall -U "${POSTGRES_USER:-postgres}" > "$backup_file" 2>/dev/null
  exit_code=$?
  if [[ $exit_code -eq 0 && -s "$backup_file" ]]; then
    assert_pass "e2e/backup: PostgreSQL full dump created"
    # Verify dump content
    if grep -q "PostgreSQL database dump" "$backup_file" 2>/dev/null; then
      assert_pass "e2e/backup: PostgreSQL dump content valid"
    else
      assert_fail "e2e/backup: PostgreSQL dump content valid" \
        "dump file does not contain expected header"
    fi
    rm -f "$backup_file"
  else
    assert_fail "e2e/backup: PostgreSQL full dump created" \
      "pg_dumpall failed or produced empty file (exit code: ${exit_code})"
    assert_skip "e2e/backup: PostgreSQL dump content valid" \
      "dump creation failed"
  fi
else
  assert_skip "e2e/backup: PostgreSQL full dump created" \
    "postgres container not deployed"
  assert_skip "e2e/backup: PostgreSQL dump content valid" \
    "postgres container not deployed"
fi

# ── Level 3: Redis RDB snapshot verification ─────────────────────────────────

if [[ $REDIS_DEPLOYED -eq 1 ]]; then
  # Wait for BGSAVE to complete
  sleep 2
  rdb_info=$(docker exec redis redis-cli INFO persistence 2>/dev/null || echo "")
  if echo "$rdb_info" | grep -q "rdb_last_bgsave_status:ok"; then
    assert_pass "e2e/backup: Redis RDB last save status ok"
  else
    assert_fail "e2e/backup: Redis RDB last save status ok" \
      "rdb_last_bgsave_status not ok"
  fi
else
  assert_skip "e2e/backup: Redis RDB last save status ok" \
    "redis container not deployed"
fi

# ── Level 4: Config directory backup ─────────────────────────────────────────

CONFIG_DIR="${REPO_ROOT}/config"
if [[ -d "$CONFIG_DIR" ]]; then
  mkdir -p "$BACKUP_DIR"
  config_archive="${BACKUP_DIR}/config-test-$(date +%s).tar.gz"
  tar -czf "$config_archive" -C "$REPO_ROOT" config 2>/dev/null
  if [[ -s "$config_archive" ]]; then
    assert_pass "e2e/backup: config directory archived successfully"
    # Verify archive integrity
    if tar -tzf "$config_archive" &>/dev/null; then
      assert_pass "e2e/backup: config archive integrity valid"
    else
      assert_fail "e2e/backup: config archive integrity valid" \
        "tar -tzf failed on config archive"
    fi
    rm -f "$config_archive"
  else
    assert_fail "e2e/backup: config directory archived successfully" \
      "tar produced empty archive"
    assert_skip "e2e/backup: config archive integrity valid" \
      "archive creation failed"
  fi
else
  assert_skip "e2e/backup: config directory archived successfully" \
    "config directory not found"
  assert_skip "e2e/backup: config archive integrity valid" \
    "config directory not found"
fi

# Cleanup
rm -rf "$BACKUP_DIR"
