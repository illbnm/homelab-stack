# Observability Stack

Full metrics, logging, and visualization for your homelab.

**Components:**
- [Prometheus](https://prometheus.io/) v3.1 — Time-series metrics collection and storage
- [Grafana](https://grafana.com/) 11.4 — Dashboards and visualization
- [Loki](https://grafana.com/oss/loki/) 3.3 — Log aggregation (Prometheus but for logs)
- [Promtail](https://grafana.com/docs/loki/latest/send-data/promtail/) — Docker log collector for Loki
- [Node Exporter](https://github.com/prometheus/node_exporter) 1.8 — Host system metrics (CPU, RAM, disk, network)
- [cAdvisor](https://github.com/google/cadvisor) 0.49 — Per-container resource metrics

## Quick Start

```bash
cp .env.example .env
nano .env  # Set DOMAIN and GRAFANA_ADMIN_PASSWORD

docker compose up -d

# Access Grafana
open https://grafana.${DOMAIN}
# Login: admin / your GRAFANA_ADMIN_PASSWORD
```

## Pre-configured Dashboards

After startup, Grafana has these dashboards ready:

| Dashboard | Description |
|-----------|-------------|
| Node Exporter Full | Host CPU, RAM, disk, network |
| Docker (cAdvisor) | Per-container resource usage |
| Loki Logs | Log exploration and search |

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DOMAIN` | Your base domain | Yes |
| `GRAFANA_ADMIN_USER` | Grafana admin username | No (default: `admin`) |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password | Yes |
| `PROMETHEUS_RETENTION` | How long to keep metrics | No (default: `30d`) |
| `PROMETHEUS_RETENTION_SIZE` | Max storage for metrics | No (default: `10GB`) |
| `TZ` | Timezone | Yes |

## Adding More Scrape Targets

Edit `prometheus/prometheus.yml` to add more services. For example, to scrape another service:

```yaml
- job_name: 'my-service'
  static_configs:
    - targets: ['my-service:9090']
```
