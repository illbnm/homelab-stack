#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/assert.sh"
[[ -f .env ]] && { set -a; source .env; set +a; }

echo "  Containers:"
for c in prometheus grafana loki alertmanager node-exporter uptime-kuma; do
  assert_container_running "$c"
done

echo "  Internal endpoints:"
skip_if_not_running "prometheus" && \
  assert_http_200 "Prometheus ready" "http://localhost:9090/-/ready" || true
skip_if_not_running "grafana" && \
  assert_http_ok "Grafana login" "http://localhost:3000/login" || true

echo "  Grafana datasources:"
[[ -n "${DOMAIN:-}" ]] && {
  assert_http_ok "Grafana UI" "https://grafana.${DOMAIN}"
  assert_http_ok "Uptime Kuma" "https://uptime.${DOMAIN}"
} || echo "    ⏭ DOMAIN not set"
