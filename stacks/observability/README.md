# Observability Stack — Full Observability Suite

Complete monitoring: Metrics (Prometheus), Logs (Loki), Traces (Tempo), Alerting (Alertmanager), Uptime (Uptime Kuma).

## Services

| Service | Image | Port | URL |
|---------|-------|------|-----|
| Prometheus | `prom/prometheus:v2.54.1` | 9090 | `https://prometheus.${DOMAIN}` |
| Grafana | `grafana/grafana:11.2.2` | 3000 | `https://grafana.${DOMAIN}` |
| Loki | `grafana/loki:3.2.0` | 3100 | `https://loki.${DOMAIN}` |
| Promtail | `grafana/promtail:3.2.0` | - | (agent) |
| Tempo | `grafana/tempo:2.6.0` | 3200 | `https://tempo.${DOMAIN}` |
| Alertmanager | `prom/alertmanager:v0.27.0` | 9093 | `https://alertmanager.${DOMAIN}` |
| cAdvisor | `gcr.io/cadvisor/cadvisor:v0.50.0` | 8080 | (internal) |
| Node Exporter | `prom/node-exporter:v1.8.2` | 9100 | (internal) |
| Uptime Kuma | `louislam/uptime-kuma:1.23.15` | 3001 | `https://status.${DOMAIN}` |
| Grafana OnCall | `grafana/oncall:v1.9.22` | 8080 | `https://oncall.${DOMAIN}` |

## Quick Start

```bash
cp .env.example .env
nano .env  # Set domain, passwords, OAuth

docker compose up -d
```

## Pre-provisioned Dashboards

Dashboards auto-load via Grafana provisioning — no manual import needed:

| Dashboard | File |
|-----------|------|
| Node Exporter Full | `node-exporter-full.json` |
| Docker Container Metrics | `docker-container-metrics.json` |
| Traefik Official | `traefik-official.json` |
| Loki Logs | `loki-dashboard.json` |
| Uptime Kuma | `uptime-kuma.json` |

## Prometheus Scrape Targets

| Job | Target | Metrics |
|-----|--------|---------|
| prometheus | localhost:9090 | Self-monitoring |
| cadvisor | cadvisor:8080 | Container CPU/mem/IO |
| node-exporter | node-exporter:9100 | Host CPU/mem/disk/net |
| traefik | traefik:8080 | Proxy metrics |
| authentik | authentik-server:9300 | SSO metrics |
| nextcloud | nextcloud:9205 | Storage metrics |
| gitea | gitea:3000 | Git hosting metrics |

## Alert Rules

### Host Alerts (`alerts/host.yml`)
- CPU > 80% for 5 min → warning
- Memory > 90% → critical
- Disk > 85% for 10 min → warning
- Disk I/O time abnormal → warning

### Container Alerts (`alerts/containers.yml`)
- Container restarts > 3/hour → warning
- Container OOM killed → critical
- Container health check failed → warning

### Service Alerts (`alerts/services.yml`)
- Traefik 5xx error rate > 1% → warning
- Response time P99 > 2s → warning

All alerts route to Alertmanager → ntfy push notifications.

## Grafana Authentik SSO

Configure in `.env`:
```
GRAFANA_OAUTH_CLIENT_ID=grafana
GRAFANA_OAUTH_CLIENT_SECRET=<your-secret>
```

Role mapping:
- `homelab-admins` group → Grafana Admin
- `homelab-users` group → Grafana Viewer

## Uptime Kuma Setup

```bash
./scripts/uptime-kuma-setup.sh yourdomain.com
```

Creates monitors for all homelab services. Status page at `https://status.${DOMAIN}` (public, no login).

## Data Retention

| Service | Default | Config |
|---------|---------|--------|
| Prometheus | 30 days | `PROMETHEUS_RETENTION` |
| Loki | 7 days | `LOKI_RETENTION` |
| Tempo | 3 days | `TEMPO_RETENTION` |

## DNS Records

| Hostname | Service |
|----------|---------|
| `prometheus.${DOMAIN}` | Prometheus |
| `grafana.${DOMAIN}` | Grafana |
| `loki.${DOMAIN}` | Loki |
| `tempo.${DOMAIN}` | Tempo |
| `alertmanager.${DOMAIN}` | Alertmanager |
| `status.${DOMAIN}` | Uptime Kuma |
| `oncall.${DOMAIN}` | Grafana OnCall |