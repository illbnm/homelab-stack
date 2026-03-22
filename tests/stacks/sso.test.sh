#!/bin/bash

source ../lib/assert.sh

test_authentik_running() {
  assert_container_running "authentik"
  assert_http_200 "http://localhost:9001/api/v3/core/users/?page_size=1"
}

test_authentik_healthy() {
  assert_container_healthy "authentik"
}