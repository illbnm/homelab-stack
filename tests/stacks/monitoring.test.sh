#!/usr/bin/env bash
assert_suite "monitoring"

test_prometheus_running() {
    assert_container_running prometheus
}

test_prometheus_healthy() {
    assert_http_200 "http://localhost:9090/-/healthy" 10
}

test_grafana_running() {
    assert_container_running grafana
}

test_grafana_healthy() {
    assert_http_200 "http://localhost:3000/api/health" 10
}

test_loki_running() {
    assert_container_running loki
}

test_prometheus_running
test_prometheus_healthy
test_grafana_running
test_grafana_healthy
test_loki_running