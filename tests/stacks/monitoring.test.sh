#!/bin/bash
# =============================================================================
# Monitoring Stack Tests
# Tests for: Prometheus, Grafana, Loki, AlertManager, cAdvisor, Node Exporter
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/assert.sh"

# -----------------------------------------------------------------------------
# Test: Docker Compose file validation
# -----------------------------------------------------------------------------
describe "Docker Compose Configuration"

COMPOSE_FILE="stacks/monitoring/docker-compose.yml"
assert_file_exists "$COMPOSE_FILE" "Monitoring compose file should exist"
assert_docker_compose_valid "$COMPOSE_FILE" "Compose file should be valid YAML"

# -----------------------------------------------------------------------------
# Test: Required services
# -----------------------------------------------------------------------------
describe "Service Definitions"

assert_service_exists "$COMPOSE_FILE" "prometheus" "Prometheus service should exist"
assert_service_exists "$COMPOSE_FILE" "grafana" "Grafana service should exist"
assert_service_exists "$COMPOSE_FILE" "loki" "Loki service should exist"
assert_service_exists "$COMPOSE_FILE" "promtail" "Promtail service should exist"
assert_service_exists "$COMPOSE_FILE" "alertmanager" "AlertManager service should exist"
assert_service_exists "$COMPOSE_FILE" "cadvisor" "cAdvisor service should exist"
assert_service_exists "$COMPOSE_FILE" "node-exporter" "Node Exporter service should exist"

# -----------------------------------------------------------------------------
# Test: Configuration files
# -----------------------------------------------------------------------------
describe "Configuration Files"

it "should have Prometheus config"
assert_file_exists "config/prometheus/prometheus.yml" "Prometheus config should exist"

it "should have Prometheus rules"
assert_dir_exists "config/prometheus/rules" "Prometheus rules directory should exist"

it "should have AlertManager config"
assert_file_exists "config/alertmanager/alertmanager.yml" "AlertManager config should exist"

it "should have Loki config"
assert_file_exists "config/loki/loki-config.yml" "Loki config should exist"

it "should have Promtail config"
assert_file_exists "config/loki/promtail-config.yml" "Promtail config should exist"

it "should have Grafana provisioning"
assert_dir_exists "config/grafana/provisioning" "Grafana provisioning should exist"

it "should have Grafana datasources"
assert_file_exists "config/grafana/provisioning/datasources/datasources.yml" "Grafana datasources should exist"

it "should have Grafana dashboards"
assert_file_exists "config/grafana/provisioning/dashboards/dashboards.yml" "Grafana dashboards should exist"

# -----------------------------------------------------------------------------
# Test: Prometheus configuration
# -----------------------------------------------------------------------------
describe "Prometheus Configuration"

COMPOSE_CONTENT=$(docker compose -f "$COMPOSE_FILE" config 2>/dev/null || echo "")

it "should configure Prometheus retention"
assert_contains "$COMPOSE_CONTENT" "storage.tsdb.retention.time" "Prometheus should have retention config"

it "should enable Prometheus API"
assert_contains "$COMPOSE_CONTENT" "web.enable-admin-api" "Prometheus admin API should be enabled"

it "should have Prometheus ports"
assert_contains "$COMPOSE_CONTENT" "9090" "Prometheus should expose port 9090"

# -----------------------------------------------------------------------------
# Test: Grafana configuration
# -----------------------------------------------------------------------------
describe "Grafana Configuration"

it "should have Grafana port"
COMPOSE_CONTENT=$(cat "$COMPOSE_FILE")
assert_contains "$COMPOSE_CONTENT" "3000" "Grafana should expose port 3000"

it "should have OAuth configuration"
assert_contains "$COMPOSE_CONTENT" "GF_AUTH_GENERIC_OAUTH" "Grafana should have OAuth config"

# -----------------------------------------------------------------------------
# Test: Networks
# -----------------------------------------------------------------------------
describe "Network Configuration"

it "should define monitoring network"
assert_contains "$COMPOSE_CONTENT" "monitoring" "Monitoring network should be defined"
assert_contains "$COMPOSE_CONTENT" "proxy" "Proxy network should be referenced"

# -----------------------------------------------------------------------------
# Test: Volumes
# -----------------------------------------------------------------------------
describe "Volume Configuration"

it "should define Prometheus volume"
assert_contains "$COMPOSE_CONTENT" "prometheus_data" "Prometheus volume should be defined"

it "should define Grafana volume"
assert_contains "$COMPOSE_CONTENT" "grafana_data" "Grafana volume should be defined"

it "should define Loki volume"
assert_contains "$COMPOSE_CONTENT" "loki_data" "Loki volume should be defined"

it "should define AlertManager volume"
assert_contains "$COMPOSE_CONTENT" "alertmanager_data" "AlertManager volume should be defined"