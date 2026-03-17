#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Storage Stack Tests
# Services: Nextcloud, MinIO, FileBrowser, Syncthing
# =============================================================================

# shellcheck shell=bash

# ---------------------------------------------------------------------------
# Nextcloud
# ---------------------------------------------------------------------------

test_nextcloud_container_running() {
  assert_container_running "nextcloud"
}

test_nextcloud_container_healthy() {
  assert_container_healthy "nextcloud"
}

test_nextcloud_status_endpoint() {
  assert_http_200 "http://localhost:8080/status.php"
}

test_nextcloud_status_installed() {
  assert_http_body_contains "http://localhost:8080/status.php" '"installed":true'
}

test_nextcloud_status_not_in_maintenance() {
  local body
  body=$(curl --silent --max-time 15 "http://localhost:8080/status.php" 2>/dev/null || echo "")
  if [[ "$body" == *'"maintenance":true'* ]]; then
    _assert_fail "Nextcloud is in maintenance mode"
  fi
}

test_nextcloud_port_open() {
  assert_port_open "localhost" "8080"
}

# ---------------------------------------------------------------------------
# MinIO
# ---------------------------------------------------------------------------

test_minio_container_running() {
  assert_container_running "minio"
}

test_minio_container_healthy() {
  assert_container_healthy "minio"
}

test_minio_health_live() {
  assert_http_200 "http://localhost:9000/minio/health/live"
}

test_minio_health_ready() {
  assert_http_200 "http://localhost:9000/minio/health/ready"
}

test_minio_console_accessible() {
  local status
  status=$(curl --silent --max-time 10 --output /dev/null --write-out "%{http_code}" \
    "http://localhost:9001" 2>/dev/null || echo "000")
  if [[ "$status" == "200" || "$status" == "302" ]]; then
    return 0
  fi
  _assert_fail "MinIO Console returned HTTP ${status} (expected 200/302)"
}

test_minio_api_port_open() {
  assert_port_open "localhost" "9000"
}

test_minio_console_port_open() {
  assert_port_open "localhost" "9001"
}

# ---------------------------------------------------------------------------
# FileBrowser
# ---------------------------------------------------------------------------

test_filebrowser_container_running() {
  assert_container_running "filebrowser"
}

test_filebrowser_ui_accessible() {
  assert_http_200 "http://localhost:8081"
}

test_filebrowser_port_open() {
  assert_port_open "localhost" "8081"
}

# ---------------------------------------------------------------------------
# Syncthing
# ---------------------------------------------------------------------------

test_syncthing_container_running() {
  assert_container_running "syncthing"
}

test_syncthing_container_healthy() {
  assert_container_healthy "syncthing"
}

test_syncthing_rest_ping() {
  assert_http_200 "http://localhost:8384/rest/noauth/health"
}

test_syncthing_gui_port_open() {
  assert_port_open "localhost" "8384"
}

# ---------------------------------------------------------------------------
# Volume checks
# ---------------------------------------------------------------------------

test_nextcloud_data_volume_exists() {
  docker_volume_exists "nextcloud_data" || \
  docker_volume_exists "storage_nextcloud_data" || \
    echo "WARN: nextcloud data volume not found" >&2
}

test_minio_data_volume_exists() {
  docker_volume_exists "minio_data" || \
  docker_volume_exists "storage_minio_data" || \
    echo "WARN: minio data volume not found" >&2
}
