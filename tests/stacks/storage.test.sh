#!/usr/bin/env bash
# =============================================================================
# Storage Stack Tests — Nextcloud, MinIO, FileBrowser
# =============================================================================

log_group "Storage"

# --- Level 1: Container health ---

STORAGE_CONTAINERS=(nextcloud minio filebrowser)

for c in "${STORAGE_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_running "$c"
    assert_container_healthy "$c"
    assert_container_not_restarting "$c"
  else
    skip_test "Container '$c'" "not running"
  fi
done

# --- Level 2: HTTP endpoints ---
if [[ "${TEST_LEVEL:-99}" -ge 2 ]]; then

  test_nextcloud_http() {
    require_container "nextcloud" || return
    assert_http_200 "http://localhost:80/status.php" "Nextcloud /status.php"
    # Verify Nextcloud is installed
    assert_http_body_contains "http://localhost:80/status.php" '"installed":true' \
      "Nextcloud reports installed:true"
  }

  test_minio_http() {
    require_container "minio" || return
    assert_http_200 "http://localhost:9000/minio/health/live" "MinIO health/live"
    assert_http_ok "http://localhost:9001" "MinIO Console"
  }

  test_filebrowser_http() {
    require_container "filebrowser" || return
    assert_http_ok "http://localhost:80" "FileBrowser Web UI"
  }

  test_nextcloud_http
  test_minio_http
  test_filebrowser_http
fi

# --- Level 3: Service interconnection ---
if [[ "${TEST_LEVEL:-99}" -ge 3 ]]; then

  # Nextcloud connects to shared PostgreSQL and Redis
  test_nextcloud_db_connection() {
    require_container "nextcloud" || return
    require_container "homelab-postgres" || return
    assert_container_on_network "nextcloud" "databases"
    assert_container_on_network "nextcloud" "proxy"
    local result
    result=$(docker_exec "homelab-postgres" \
      psql -U "${POSTGRES_ROOT_USER:-postgres}" -d nextcloud -c "SELECT 1;" 2>/dev/null)
    assert_contains "$result" "1" "Nextcloud database query succeeds"
  }

  test_nextcloud_db_connection
fi

# --- Image tags ---
for c in "${STORAGE_CONTAINERS[@]}"; do
  if is_container_running "$c"; then
    assert_container_image_not_latest "$c"
  fi
done
