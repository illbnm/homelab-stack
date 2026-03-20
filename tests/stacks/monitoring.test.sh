#!/bin/bash

source ../lib/assert.sh

test_grafana_running() {
  assert_container_running "grafana"
  assert_http_200 "http://localhost:3000/api/health"
}

test_prometheus_running() {
  assert_container_running "prometheus"
  assert_http_200 "http://localhost:9090/-/healthy"
}

test_prometheus_scrape_cadvisor() {
  local result=$(curl -s "http://localhost:9090/api/v1/query?query=up{job='cadvisor'}")
  assert_json_value "$result" ".data.result[0].value[1]" "1"
}