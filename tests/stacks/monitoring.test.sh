# Monitoring/Observability stack tests

CURRENT_TEST="prometheus_running"
assert_container_running "prometheus"

CURRENT_TEST="prometheus_healthy"
assert_container_healthy "prometheus"

CURRENT_TEST="prometheus_http"
assert_http_200 "http://localhost:9090/-/healthy"

CURRENT_TEST="prometheus_targets"
local targets=$(curl -sf "http://localhost:9090/api/v1/targets" 2>/dev/null || echo "{}")
assert_contains "$targets" "cadvisor" "Prometheus scrapes cAdvisor"

CURRENT_TEST="prometheus_scrape_cadvisor"
local cadvisor_up=$(curl -sf "http://localhost:9090/api/v1/query?query=up{job='cadvisor'}" 2>/dev/null || echo "{}")
assert_contains "$cadvisor_up" "value" "cAdvisor target is up"

CURRENT_TEST="grafana_running"
assert_container_running "grafana"

CURRENT_TEST="grafana_healthy"
assert_container_healthy "grafana"

CURRENT_TEST="grafana_http"
assert_http_200 "http://localhost:3000/api/health"

CURRENT_TEST="grafana_datasource_prometheus"
local ds=$(curl -sf -u admin:admin "http://localhost:3000/api/datasources/name/Prometheus" 2>/dev/null || echo "{}")
assert_contains "$ds" "url" "Grafana has Prometheus datasource"

CURRENT_TEST="loki_running"
assert_container_running "loki"

CURRENT_TEST="loki_healthy"
assert_container_healthy "loki"

CURRENT_TEST="loki_ready"
assert_http_200 "http://localhost:3100/ready"

CURRENT_TEST="promtail_running"
assert_container_running "promtail"

CURRENT_TEST="tempo_running"
assert_container_running "tempo"

CURRENT_TEST="tempo_healthy"
assert_container_healthy "tempo"

CURRENT_TEST="alertmanager_running"
assert_container_running "alertmanager"

CURRENT_TEST="alertmanager_healthy"
assert_container_healthy "alertmanager"

CURRENT_TEST="cadvisor_running"
assert_container_running "cadvisor"

CURRENT_TEST="node_exporter_running"
assert_container_running "node-exporter"

CURRENT_TEST="node_exporter_metrics"
assert_http_200 "http://localhost:9100/metrics"

CURRENT_TEST="uptime_kuma_running"
assert_container_running "uptime-kuma"

CURRENT_TEST="uptime_kuma_healthy"
assert_container_healthy "uptime-kuma"
