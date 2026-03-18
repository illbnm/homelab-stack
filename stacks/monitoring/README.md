# HomeLab Monitoring Stack — README

## Overview

Complete observability stack for the homelab: metrics, logs, traces, alerts, and status page.

## Architecture

```
                    ┌──────────────────────────────────────┐
                    │           Traefik (Reverse Proxy)     │
                    └──────┬──────┬──────┬──────┬─────────┘
                           │      │      │      │
                    ┌──────▼┐ ┌───▼────┐ ┌▼─────┐ ┌▼──────────┐
                    │Grafana│ │Prometh.│ │ Loki │ │Uptime Kuma│
                    └──┬──┬─┘ └───┬────┘ └──┬───┘ └───────────┘
                       │  │       │        │
              ┌────────┘  │  ┌────┘   ┌────┘
              │           │  │        │
         ┌────▼────┐  ┌───▼──▼──┐  ┌──▼──────┐
         │  Tempo   │  │Alertmgr│  │ Promtail│
         │ (Traces) │  │        │  │ (Logs)  │
         └─────────┘  └───┬────┘  └─────────┘
                          │
                     ┌────▼────┐
                     │  ntfy   │
                     │(Push)   │
                     └─────────┘
```

## Services

| Service | Port | URL | Description |
|---------|------|-----|-------------|
| Prometheus | 9090 | `prometheus.{DOMAIN}` | Metrics collection & alerting |
| Grafana | 3000 | `grafana.{DOMAIN}` | Dashboards & visualization |
| Loki | 3100 | internal | Log aggregation |
| Tempo | 3200 | internal | Distributed tracing |
| Alertmanager | 9093 | internal | Alert routing & notification |
| Promtail | 9080 | internal | Log collection agent |
| Uptime Kuma | 3001 | `status.{DOMAIN}` | Status page & uptime monitoring |
| cAdvisor | 8080 | internal | Container metrics |
| Node Exporter | 9100 | internal | Host metrics |

## Quick Start

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env with your domain and credentials

# 2. Start the stack
cd stacks/monitoring
docker compose up -d

# 3. Download community dashboards
cd ../..
./scripts/download-grafana-dashboards.sh
# Restart Grafana to load dashboards
cd stacks/monitoring && docker compose restart grafana

# 4. Set up Uptime Kuma monitors
./scripts/uptime-kuma-setup.sh
# Then visit status.{DOMAIN} to configure notification channels
```

## Configuration

### Prometheus Scrape Targets

Targets are defined in `config/prometheus/prometheus.yml`:
- **node-exporter** — Host CPU, memory, disk, network
- **cadvisor** — Container resource usage
- **traefik** — HTTP traffic, latency, errors
- **loki** — Loki internal metrics
- **alertmanager** — Alert pipeline metrics
- **tempo** — Tracing pipeline metrics
- **authentik-server/worker** — SSO metrics
- **nextcloud** — Nextcloud metrics
- **gitea** — Gitea metrics

### Alert Rules

Located in `config/prometheus/alerts/`:

| File | Alerts |
|------|--------|
| `host.yml` | CPU > 80%, Memory > 90%, Disk > 85%/95% |
| `containers.yml` | Restart > 3/h, OOM, health check fail, CPU throttle |
| `services.yml` | Traefik 5xx > 1%, P99 > 2s, backend down |
| `rules/homelab.yml` | Legacy rules (ContainerDown, HighCPU, etc.) |

### Grafana Dashboards

Community dashboards provisioned via `config/grafana/dashboards/homelab/`:

| Dashboard | ID | Description |
|-----------|----|-------------|
| Node Exporter Full | 1860 | Complete host metrics |
| Docker Container | 179 | Container resource overview |
| Traefik | 17346 | HTTP traffic & routing |
| Loki | 13639 | Log exploration |
| Uptime Kuma | 18278 | Service uptime stats |

### Log Collection (Promtail)

Promtail collects logs from:
- **Docker containers** — Auto-discovered via Docker socket
- **System logs** — `/var/log/*.log`
- **Syslog** — `/var/log/syslog`
- **Systemd journal** — All unit logs (last 12h)

### Tracing (Tempo)

Tempo receives traces via:
- **OTLP** (HTTP :4318, gRPC :4319)
- **Jaeger** (gRPC :14250, Thrift HTTP :14268)

Traces are automatically linked to logs (Loki) and metrics (Prometheus) in Grafana.

### Notifications

Alerts flow: Prometheus → Alertmanager → ntfy → your devices.

## Data Retention

Configurable via `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `PROMETHEUS_RETENTION` | 30d | Metrics retention |
| `LOKI_RETENTION` | 30d | Log retention (set in loki-config.yml) |
| `TEMPO_RETENTION` | 24h | Trace retention |

## Volumes

All data is stored in Docker named volumes:
- `prometheus_data`, `grafana_data`, `loki_data`
- `alertmanager_data`, `tempo_data`, `uptime_kuma_data`

## Maintenance

```bash
# Check service health
docker compose ps

# View logs
docker compose logs -f prometheus
docker compose logs -f grafana

# Reload Prometheus config (no restart needed)
curl -X POST http://localhost:9090/-/reload

# Backup data
docker run --rm -v prometheus_data:/data -v $(pwd):/backup alpine tar czf /backup/prometheus-backup.tar.gz /data

# Update
docker compose pull && docker compose up -d
```
