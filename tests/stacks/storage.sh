#!/usr/bin/env bash
# Storage stack tests
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

test_nextcloud_running() {
  assert_container_running "nextcloud"
  assert_http_response "http://localhost:8080/status.php" "installed"
}

test_minio_running() {
  assert_container_running "minio"
  assert_http_200 "http://localhost:9001"
}

test_filebrowser_running() {
  assert_container_running "filebrowser"
  assert_http_200 "http://localhost:8081"
}

test_syncthing_running() {
  assert_container_running "syncthing"
  assert_http_200 "http://localhost:8384"
}

run_test test_nextcloud_running
run_test test_minio_running
run_test test_filebrowser_running
run_test test_syncthing_running
