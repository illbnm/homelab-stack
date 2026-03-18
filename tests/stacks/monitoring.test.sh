#!/usr/bin/env/bash
# =============================================================================# Monitoring Stack Tests
# Tests for Prometheus, Grafana, Loki, Alertmanager
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
source "$SCRIPT_DIR/../lib/assert.sh"
source "$SCRIPT_DIR/../lib/docker.sh"
source "$SCRIPT_DIR/../lib/report.sh"

print_section "Monitoring"

# Test containers
container_check prometheus
container_check grafana
container_check loki
container_check alertmanager

# Test HTTP endpoints
http_check Prometheus "http://localhost:9090/-/healthy"
http_check Grafana "http://localhost:3000/api/health"
http_check Alertmanager "http://localhost:9093/-/healthy"