#!/usr/bin/env bash
# =============================================================================
# Storage Stack Tests
# =============================================================================

test_nextcloud_running() {
  assert_container_running "nextcloud"
}

test_nextcloud_http() {
  assert_http_200 "http://localhost:8080" 10
}

test_minio_running() {
  assert_container_running "minio"
}

test_minio_http() {
  assert_http_200 "http://localhost:9001" 10
}

test_filebrowser_running() {
  assert_container_running "filebrowser"
}

run_test_with_timing "storage" test_nextcloud_running "Nextcloud running"
run_test_with_timing "storage" test_nextcloud_http "Nextcloud HTTP 200"
run_test_with_timing "storage" test_minio_running "MinIO running"
run_test_with_timing "storage" test_minio_http "MinIO console HTTP 200"
run_test_with_timing "storage" test_filebrowser_running "FileBrowser running"
