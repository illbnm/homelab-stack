# Observability Stack

The complete observability suite covering the three pillars (Metrics, Logs, Traces) along with proactive alerting and SLA tracking.

## Included Services

- **Prometheus**: Time-series metrics collection.
- **Grafana**: Beautiful dashboards and data visualization. Pre-configured with SSO.
- **Loki & Promtail**: Log aggregation for all Docker containers and system logs.
- **Tempo**: Distributed tracing.
- **Alertmanager & Grafana OnCall**: Alert routing and on-call schedule management.
- **cAdvisor & Node Exporter**: Harvesters for container and host metrics.
- **Uptime Kuma**: SLA and Uptime monitoring with a public status page.

## Setup & Configuration

1. Copy `.env.example` to `.env` and adjust passwords and retention values.
2. Start the stack:
   ```bash
   docker compose up -d
   ```
3. Initialize the Uptime Kuma monitors automatically by running the setup script from the root of the repository:
   ```bash
   ./scripts/uptime-kuma-setup.sh "your_admin_user" "your_admin_password"
   ```

## Automated Provisioning

Grafana is pre-configured to automatically provision:
- Data sources (Prometheus, Loki, Tempo) internally.
- Required Dashboards from the JSONs present in `config/observability/grafana/provisioning/dashboards`.

Prometheus is pre-configured to scrape the host, containers, Traefik, Authentik, Nextcloud, and Gitea. Alerting rules for high CPU, Memory, OOM, latency, and HTTP 5xx errors are included in `config/observability/prometheus/alerts/*.yml`.
