#!/bin/bash

test_nextcloud_running() {
  assert_container_running "nextcloud"
  assert_http_200 "http://localhost:8080/status.php"
}