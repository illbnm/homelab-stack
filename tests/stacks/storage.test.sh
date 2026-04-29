#!/usr/bin/env bash
assert_suite "storage"

test_nextcloud_running() {
    assert_container_running nextcloud
}

test_nextcloud_status() {
    assert_http_response "http://localhost:80/status.php" '"installed":true'
}

test_minio_running() {
    assert_container_running minio
}

test_minio_console() {
    assert_http_200 "http://localhost:9001" 10
}

test_filebrowser_running() {
    assert_container_running filebrowser
}

test_syncthing_running() {
    assert_container_running syncthing
}

test_nextcloud_running
test_nextcloud_status
test_minio_running
test_minio_console
test_filebrowser_running
test_syncthing_running