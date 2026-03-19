#!/bin/bash

source ../lib/assert.sh

test_adguard_running() {
  assert_container_running "adguard"
  assert_http_200 "http://localhost:3000/control/status"
}

test_wireguard_easy_running() {
  assert_container_running "wireguard-easy"
}