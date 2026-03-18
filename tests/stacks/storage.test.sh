#!/usr/bin/env bash
# =============================================================================
# storage.test.sh — Storage stack tests
# Services: Nextcloud, MinIO, FileBrowser
# =============================================================================

# --- Nextcloud ---

test_nextcloud_running() {
  assert_container_running "nextcloud"
}

test_nextcloud_healthy() {
  assert_container_healthy "nextcloud"
}

test_nextcloud_status() {
  assert_http_200 "http://localhost:8080/status.php" 15
}

test_nextcloud_installed() {
  assert_http_body_contains "http://localhost:8080/status.php" '"installed":true' 15
}

test_nextcloud_no_crash_loop() {
  assert_no_crash_loop "nextcloud" 3
}

test_nextcloud_in_proxy_network() {
  assert_container_in_network "nextcloud" "proxy"
}

# --- MinIO ---

test_minio_running() {
  assert_container_running "minio"
}

test_minio_healthy() {
  assert_container_healthy "minio"
}

test_minio_api() {
  assert_http_200 "http://localhost:9000/minio/health/live" 10
}

test_minio_console() {
  assert_http_200 "http://localhost:9001" 10
}

test_minio_no_crash_loop() {
  assert_no_crash_loop "minio" 3
}

# --- FileBrowser ---

test_filebrowser_running() {
  assert_container_running "filebrowser"
}

test_filebrowser_healthy() {
  assert_container_healthy "filebrowser"
}

test_filebrowser_ui() {
  assert_http_200 "http://localhost:8081" 10
}

test_filebrowser_no_crash_loop() {
  assert_no_crash_loop "filebrowser" 3
}
