# Observability Stack

Full observability: Metrics (Prometheus), Logs (Loki), Traces (Tempo), Alerting (Alertmanager), Uptime (Uptime Kuma).

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Prometheus | `prom/prometheus:v2.54.1` | 9090 | Metrics collection |
| Grafana | `grafana/grafana:11.2.2` | 3000 | Visualization dashboards |
| Loki | `grafana/loki:3.2.0` | 3100 | Log aggregation |
| Promtail | `grafana/promtail:3.2.0` | — | Log collection agent |
| Tempo | `grafana/tempo:2.6.0` | 3200 | Distributed tracing |
| Alertmanager | `prom/alertmanager:v0.27.0` | 9093 | Alert routing |
| cAdvisor | `gcr.io/cadvisor/cadvisor:v0.50.0` | 8080 | Container metrics |
| Node Exporter | `prom/node-exporter:v1.8.2` | 9100 | Host metrics |
| Uptime Kuma | `louislam/uptime-kuma:1.23.15` | 3001 | Uptime monitoring |

## Quick Start

```bash
cp .env.example .env
# Edit .env — set DOMAIN, GRAFANA_ADMIN_PASSWORD
docker compose up -d

# Import dashboards
./scripts/grafana-import-dashboards.sh

# Setup Uptime Kuma monitors
./scripts/uptime-kuma-setup.sh
```

## Pre-provisioned Dashboards

Run `scripts/grafana-import-dashboards.sh` after Grafana is healthy:

| Dashboard | Grafana.com ID |
|-----------|---------------|
| Node Exporter Full | 1860 |
| Docker Container & Host Metrics | 179 |
| Traefik Official | 17346 |
| Loki Dashboard | 13639 |
| Uptime Kuma | 18278 |

Datasources (Prometheus, Loki, Tempo) are auto-provisioned via `config/grafana/provisioning/datasources/`.

## Alert Rules

| Rule | Severity | Condition |
|------|----------|-----------|
| HighCPU | warning | CPU > 80% for 5min |
| HighMemory | critical | Memory > 90% for 5min |
| HighDisk | warning | Disk > 85% for 10min |
| DiskIOAnomaly | warning | Disk IO > 0.5s/s for 10min |
| ContainerRestart | warning | >3 restarts/hour |
| ContainerOOM | critical | OOM event detected |
| ContainerHealthcheckFail | warning | Unhealthy for 5min |
| Traefik5xx | warning | 5xx rate > 1% for 5min |
| HighResponseTime | warning | P99 > 2s for 10min |

All alerts route to Alertmanager → ntfy webhook.

## Uptime Kuma

- Public status page: `https://status.${DOMAIN}`
- Run `scripts/uptime-kuma-setup.sh` for setup instructions
- Add monitors via web UI, then create a public status page

## Grafana OIDC (Authentik)

Set in `.env`:
```
GRAFANA_OAUTH_CLIENT_ID=<from authentik-setup.sh>
GRAFANA_OAUTH_CLIENT_SECRET=<from authentik-setup.sh>
AUTHENTIK_DOMAIN=auth.example.com
```

- `homelab-admins` group → Grafana Admin
- `homelab-users` group → Grafana Viewer

## Data Retention

| Service | Default | Variable |
|---------|---------|----------|
| Prometheus | 30d | `PROMETHEUS_RETENTION` |
| Loki | 7d | `LOKI_RETENTION` |
| Tempo | 3d | `TEMPO_RETENTION` |

Generated/reviewed with: claude-opus-4-6