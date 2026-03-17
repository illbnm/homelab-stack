#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Storage Stack Tests
# =============================================================================
# Tests: Nextcloud, MinIO, FileBrowser, Syncthing
# =============================================================================

# ---------------------------------------------------------------------------
# Level 1 — Container Health
# ---------------------------------------------------------------------------

test_nextcloud_running() {
  assert_container_running "nextcloud"
}

test_nextcloud_healthy() {
  assert_container_healthy "nextcloud" 120
}

test_minio_running() {
  assert_container_running "minio"
}

test_minio_healthy() {
  assert_container_healthy "minio" 60
}

test_filebrowser_running() {
  assert_container_running "filebrowser"
}

test_filebrowser_healthy() {
  assert_container_healthy "filebrowser" 60
}

test_syncthing_running() {
  assert_container_running "syncthing"
}

test_syncthing_healthy() {
  assert_container_healthy "syncthing" 60
}

# ---------------------------------------------------------------------------
# Level 2 — HTTP Endpoints
# ---------------------------------------------------------------------------

test_nextcloud_status() {
  assert_http_200 "http://localhost:8080/status.php" 30
}

test_nextcloud_installed() {
  assert_http_response "http://localhost:8080/status.php" '"installed":true' 30
}

test_minio_health() {
  assert_http_200 "http://localhost:9000/minio/health/live" 30
}

test_minio_console() {
  assert_http_200 "http://localhost:9001" 30
}

test_filebrowser_webui() {
  assert_http_200 "http://localhost:8081" 30
}

test_syncthing_webui() {
  assert_http_200 "http://localhost:8384" 30
}

# ---------------------------------------------------------------------------
# Level 1 — Network
# ---------------------------------------------------------------------------

test_nextcloud_on_internal_network() {
  assert_container_on_network "nextcloud" "internal"
}

test_minio_on_internal_network() {
  assert_container_on_network "minio" "internal"
}

# ---------------------------------------------------------------------------
# Level 1 — Configuration
# ---------------------------------------------------------------------------

test_storage_compose_valid() {
  local compose_file="${PROJECT_ROOT}/stacks/storage/docker-compose.yml"

  if [[ ! -f "${compose_file}" ]]; then
    _assert_skip "Storage compose file not found"
    return 0
  fi

  assert_compose_valid "${compose_file}"
}
