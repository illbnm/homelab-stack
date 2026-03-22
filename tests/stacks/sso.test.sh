#!/bin/bash

source ../lib/assert.sh

test_authentik_running() {
  assert_container_running "authentik"
  assert_http_200 "http://localhost:9001/api/v3/core/users/?page_size=1"
}

test_authentik_grafana_connection() {
  local result=$(curl -s -u admin:${GF_ADMIN_PASSWORD} "http://localhost:3000/api/datasources/name/Prometheus")
  assert_json_key_exists "$result" ".url"
}