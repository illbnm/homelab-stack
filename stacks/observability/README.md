# 📊 Observability Stack (Metrics, Logs, Traces, Alerts, Uptime)

Complete operational visibility suite covering the 3 pillars of observability and real-time SLA monitors.

## 📦 Services
- **Prometheus (`v2.54.1`):** Metrics aggregation engine with 30-day TSDB retention.
- **Grafana (`11.2.2`):** Automated pre-provisioned dashboards (Node Exporter, cAdvisor, Traefik, Loki) and Authentik SSO.
- **Loki (`3.2.0`):** Log indexing and streaming daemon.
- **Promtail (`3.2.0`):** Automatic Docker socket container log forwarder.
- **cAdvisor (`v0.50.0`):** Real-time container CPU, RAM, and network metrics.
- **Node Exporter (`v1.8.2`):** Bare-metal host hardware instrumentation.
- **Alertmanager (`v0.27.0`):** Alert routing with direct webhook dispatch to ntfy.
- **Uptime Kuma (`1.23.15`):** Public status page and SLA heartbeat monitor.
