#!/usr/bin/env bash
# Monitoring Stack — Prometheus, Grafana, Loki, Alertmanager tests
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$(dirname "$SCRIPT_DIR")/lib/assert.sh"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
if [ -f "$ROOT_DIR/.env" ]; then set -a; source "$ROOT_DIR/.env"; set +a; fi

describe "Monitoring"

it "prometheus running"; assert_container_running "prometheus"
it "prometheus healthy"; assert_http_200 "http://localhost:9090/-/healthy"
it "prometheus ready"; assert_http_200 "http://localhost:9090/-/ready"
it "prometheus config valid"; assert_file_exists "${ROOT_DIR}/config/prometheus/prometheus.yml"
it "prometheus targets up";
  local resp
  resp=$(curl -sf "http://localhost:9090/api/v1/targets" 2>/dev/null || echo '{}')
  assert_json_value "$resp" ".data.activeTargets | length >= 0" "true" "no targets"

it "grafana running"; assert_container_running "grafana"
it "grafana healthy"; assert_http_200 "http://localhost:3000/api/health"
it "grafana provisioned datasources"; assert_file_exists "${ROOT_DIR}/config/grafana/provisioning/datasources/datasources.yml"
it "grafana OIDC config"; assert_file_contains "${ROOT_DIR}/config/grafana/grafana.ini" "generic_oauth"

it "loki running"; assert_container_running "loki"
it "loki ready"; assert_http_200 "http://localhost:3100/ready"

it "alertmanager running"; assert_container_running "alertmanager"
it "alertmanager healthy"; assert_http_200 "http://localhost:9093/-/healthy"
it "alertmanager ntfy receiver configured";
  assert_file_contains "${ROOT_DIR}/config/alertmanager/alertmanager.yml" "ntfy"