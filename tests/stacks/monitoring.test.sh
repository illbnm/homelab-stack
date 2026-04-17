#!/usr/bin/env bash
# tests/stacks/monitoring.test.sh

describe "Monitoring Stack (Prometheus + Grafana)"

it "Prometheus container is running"
if container_exists "prometheus"; then
    assert_container_running "prometheus"
    it "Prometheus health endpoint responds"
    assert_http_200 "http://localhost:9090/-/healthy" 10
    it "Prometheus targets page loads"
    assert_http_200 "http://localhost:9090/targets" 10
    it "Prometheus is not crash-looping"
    assert_container_restarted "prometheus" 3
else
    skip "Prometheus not found"
fi

it "Grafana container is running"
if container_exists "grafana"; then
    assert_container_running "grafana"
    it "Grafana health endpoint responds"
    assert_http_200 "http://localhost:3000/api/health" 10
    it "Grafana is not crash-looping"
    assert_container_restarted "grafana" 3
else
    skip "Grafana not found"
fi
