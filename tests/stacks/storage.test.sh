test_nextcloud_running() {
  assert_container_running "nextcloud"
  assert_container_healthy "nextcloud"
}

test_minio_running() {
  assert_container_running "minio"
  assert_container_healthy "minio"
}

test_filebrowser_running() {
  assert_container_running "filebrowser"
  assert_container_healthy "filebrowser"
}

