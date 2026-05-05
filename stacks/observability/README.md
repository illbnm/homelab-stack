
# Observability Stack

This stack provides a complete observability solution using Prometheus, Grafana, Loki, and Promtail.

## Services

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Loki**: Log aggregation system
- **Promtail**: Log collection agent

## Setup

1. Copy `.env.example` to `.env` and update the environment variables.
2. Ensure the `DATA_DIR` exists and is writable by the services.
3. Deploy the stack using `docker-compose up -d`.

## Configuration

- **Prometheus**: Configured to scrape metrics from itself and Docker daemon.
- **Grafana**: Automatically provisioned with Prometheus and Loki as data sources.
- **Loki & Promtail**: Configured to collect logs from Docker containers.

## Access

- Grafana is accessible at `https://grafana.${DOMAIN}`.
- Prometheus, Loki, and Promtail are internal services and not exposed externally.
