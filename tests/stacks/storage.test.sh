#!/bin/bash
# storage.test.sh - Storage Stack 测试
# 测试 Nextcloud, MinIO, FileBrowser, Syncthing

set -u

# Nextcloud 测试
test_nextcloud_running() {
    assert_container_running "nextcloud"
}

test_nextcloud_http() {
    assert_http_response "http://localhost:8080/status.php" "installed" "Nextcloud status"
}

# MinIO 测试
test_minio_running() {
    assert_container_running "minio"
}

test_minio_http() {
    assert_http_200 "http://localhost:9001/minio/health/live"
}

test_minio_api() {
    assert_http_response "http://localhost:9001/minio/bootstrap/v1/verify" "" "MinIO bootstrap"
}

# FileBrowser 测试
test_filebrowser_running() {
    assert_container_running "filebrowser"
}

test_filebrowser_http() {
    assert_http_200 "http://localhost:8081/login"
}

# Syncthing 测试
test_syncthing_running() {
    assert_container_running "syncthing"
}

test_syncthing_http() {
    assert_http_200 "http://localhost:8384/rest/system/status"
}
