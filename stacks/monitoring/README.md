# Monitoring / Observability Stack

Complete observability stack: Metrics, Logs, Traces, Alerting, and Uptime monitoring.

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| Grafana | `https://grafana.${DOMAIN}` | Visualization & dashboards |
| Prometheus | `https://prometheus.${DOMAIN}` | Metrics collection |
| Loki | Internal | Log aggregation |
| Tempo | `https://tempo.${DOMAIN}` | Distributed tracing |
| Alertmanager | `https://alerts.${DOMAIN}` | Alert routing |
| Uptime Kuma | `https://uptime.${DOMAIN}` | Uptime monitoring |
| Status Page | `https://status.${DOMAIN}` | Public status (no auth) |
| Grafana OnCall | `https://oncall.${DOMAIN}` | On-call management |

## Quick Start

```bash
cd stacks/monitoring
cp .env.example .env
# Edit .env with your domain, passwords, ntfy topic
docker compose up -d
```

## Grafana

### Data Sources (auto-provisioned)
- **Prometheus** — `http://prometheus:9090` (default)
- **Loki** — `http://loki:3100`
- **Tempo** — `http://tempo:3200` (traces-to-logs & traces-to-metrics)

### Pre-loaded Dashboards

| Dashboard | UID | Grafana.com ID |
|-----------|-----|----------------|
| Node Exporter Full | `node-exporter-full` | 1860 |
| Docker Container & Host | `docker-container-host` | 179 |
| Traefik Official | `traefik-official` | 17346 |
| Loki Dashboard | `loki-dashboard` | 13639 |
| Uptime Kuma | `uptime-kuma` | 18278 |

Loki Explore shortcut: `/d/logs/logs`

### Auth (Authentik OIDC)
- `homelab-admins` → Grafana **Admin**
- `homelab-users` → Grafana **Viewer**

## Alerting

### Rules
- **Host** (`config/prometheus/rules/host.yml`): CPU >80%, Memory >90%, Disk <15%, Disk IO
- **Containers** (`containers.yml`): Restart >3/h, OOM, Down
- **Services** (`services.yml`): Traefik 5xx >1%, P99 >2s

### Notification
All alerts → Alertmanager → ntfy webhook

```
NTFY_URL=https://ntfy.sh
NTFY_TOPIC=homelab-alerts
```

## Uptime Kuma

```bash
chmod +x scripts/uptime-kuma-setup.sh
./scripts/uptime-kuma-setup.sh
```

Public status page: `https://status.${DOMAIN}`

## Data Retention

| Service | Default | Env Var |
|---------|---------|---------|
| Prometheus | 30d | `PROMETHEUS_RETENTION` |
| Loki | 7d | `LOKI_RETENTION` |
| Tempo | 3d | `TEMPO_RETENTION` |
