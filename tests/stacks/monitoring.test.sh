#!/usr/bin/env bash
set -euo pipefail

test_prometheus_running() { assert_container_healthy prometheus; }
test_grafana_running() { assert_container_healthy grafana; }
test_loki_running() { assert_container_healthy loki; }
test_alertmanager_running() { assert_container_healthy alertmanager; }

test_prometheus_http() { assert_http_200 "http://localhost:9090/-/healthy"; }
test_grafana_http() { assert_http_200 "http://localhost:3000/api/health"; }
