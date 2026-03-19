#!/usr/bin/env bash
# =============================================================================
# storage.test.sh — Storage stack tests (nextcloud, minio, filebrowser)
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1: Container health
# ---------------------------------------------------------------------------
test_suite "Storage — Containers"

test_nextcloud_running() {
  assert_container_running "nextcloud"
  assert_container_healthy "nextcloud"
}

test_minio_running() {
  assert_container_running "minio"
  assert_container_healthy "minio"
}

test_filebrowser_running() {
  assert_container_running "filebrowser"
  assert_container_healthy "filebrowser"
}

test_nextcloud_running
test_minio_running
test_filebrowser_running

# ---------------------------------------------------------------------------
# Level 2: HTTP endpoints
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 2 ]]; then
  test_suite "Storage — HTTP Endpoints"

  test_nextcloud_status() {
    local body
    body=$(curl -sf --connect-timeout 5 --max-time 10 "http://localhost:80/status.php" 2>/dev/null || echo "")
    if [[ -n "$body" ]]; then
      assert_contains "$body" "installed" "Nextcloud /status.php returns installed status"
    else
      test_fail "Nextcloud /status.php" "empty or unreachable"
    fi
  }

  test_minio_health() {
    assert_http_200 "http://localhost:9000/minio/health/live" "MinIO health /minio/health/live"
  }

  test_minio_console() {
    assert_http_200 "http://localhost:9001" "MinIO Console port 9001"
  }

  test_filebrowser_ui() {
    assert_http_200 "http://localhost:8080" "FileBrowser UI"
  }

  test_nextcloud_status
  test_minio_health
  test_minio_console
  test_filebrowser_ui
fi

# ---------------------------------------------------------------------------
# Level 3: Service interconnection
# ---------------------------------------------------------------------------
if [[ ${TEST_LEVEL:-99} -ge 3 ]]; then
  test_suite "Storage — Interconnection"

  test_nextcloud_db_connection() {
    # Nextcloud uses the shared PostgreSQL from databases stack
    local result
    result=$(docker_run_in "homelab-postgres" \
      psql -U "${POSTGRES_ROOT_USER:-postgres}" -lqt 2>/dev/null | grep -c "nextcloud" || echo "0")
    if [[ "$result" -gt 0 ]]; then
      test_pass "Nextcloud database exists in PostgreSQL"
    else
      test_skip "Nextcloud database check" "database not found or not using shared postgres"
    fi
  }

  test_nextcloud_db_connection
fi
