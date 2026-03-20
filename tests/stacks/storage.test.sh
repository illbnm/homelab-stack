#!/bin/bash

source ../lib/assert.sh

test_nextcloud_running() {
  assert_container_running "nextcloud"
  assert_http_200 "http://localhost:8080/status.php"
  assert_http_response "http://localhost:8080/status.php" '"installed":true'
}

test_minio_running() {
  assert_container_running "minio"
}