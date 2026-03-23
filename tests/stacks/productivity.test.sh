#!/bin/bash

source ../lib/assert.sh

test_gitea_running() {
  assert_container_running "gitea"
  assert_http_200 "http://localhost:3001/api/v1/version"
}

test_vaultwarden_running() {
  assert_container_running "vaultwarden"
}