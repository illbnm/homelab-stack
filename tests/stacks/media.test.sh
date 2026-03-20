#!/bin/bash

source ../lib/assert.sh

test_jellyfin_running() {
  assert_container_running "jellyfin"
  assert_http_200 "http://localhost:8096/health"
}

test_sonarr_running() {
  assert_container_running "sonarr"
  assert_http_200 "http://localhost:8989/api/v3/version"
}