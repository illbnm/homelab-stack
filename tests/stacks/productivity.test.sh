#!/bin/bash

test_gitea_running() {
  assert_container_running "gitea"
  assert_http_200 "http://localhost:3000/api/v1/version"
}

test_vaultwarden_running() {
  assert_container_running "vaultwarden"
}