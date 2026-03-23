#!/usr/bin/env bash
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib"; pwd)"
source "$_LIB_DIR/assert.sh"

test_storage_nextcloud_running() { assert_container_running "nextcloud" "Nextcloud should be running"; }
test_storage_minio_running() { assert_container_running "minio" "MinIO should be running"; }
test_storage_minio_http() { assert_http_200 "http://localhost:9001" 15 "MinIO console should respond"; }
test_storage_filebrowser_running() { assert_container_running "filebrowser" "FileBrowser should be running"; }
test_storage_no_latest_tags() { assert_no_latest_images "$BASE_DIR/stacks/storage" "Storage stack should pin image versions"; }
