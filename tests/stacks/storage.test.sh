#!/bin/bash

test_nextcloud_running() {
  assert_container_running "nextcloud"
  local result=$(curl -s "http://localhost:8080/status.php")
  assert_http_response "$result" '"installed":true'
}

test_minio_running() {
  assert_container_running "minio"
}