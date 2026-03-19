#!/usr/bin/env bash
# =============================================================================
# tests/stacks/storage.test.sh — Storage Stack (Nextcloud + MinIO + FileBrowser + Syncthing)
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
source "$SCRIPT_DIR/tests/lib/assert.sh"
source "$SCRIPT_DIR/tests/lib/docker.sh"

test_nextcloud_running() {
  assert_container_running "nextcloud"
}

test_nextcloud_healthy() {
  assert_container_healthy "nextcloud" 120
}

test_nextcloud_status() {
  local code
  code=$(http_status "http://localhost:11080/status.php" 10)
  assert_contains "200 302" "$code"
}

test_minio_running() {
  assert_container_running "minio"
}

test_minio_console() {
  assert_http_200 "http://localhost:9001" 10
}

test_filebrowser_running() {
  assert_container_running "filebrowser"
}

test_filebrowser_http() {
  local code
  code=$(http_status "http://localhost:14080" 10)
  assert_contains "200 302 401" "$code"
}

test_storage_compose_valid() {
  assert_compose_valid "$SCRIPT_DIR/stacks/storage/docker-compose.yml"
}
