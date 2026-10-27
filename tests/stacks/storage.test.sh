#!/usr/bin/env bash
set -euo pipefail

test_nextcloud_running() { assert_container_healthy nextcloud; }
test_minio_running() { assert_container_healthy minio; }
test_filebrowser_running() { assert_container_healthy filebrowser; }

test_nextcloud_http() { assert_http_200 "http://localhost/status.php"; }
