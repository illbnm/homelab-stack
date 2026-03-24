# Observability Stack — Prometheus + Grafana + Loki + Alerting + Uptime Kuma

Complete observability solution covering Metrics, Logs, Alerting, and Uptime monitoring for the HomeLab stack.

## Architecture

```
                  ┌─────────────┐
                  │   Grafana   │ ← https://grafana.DOMAIN
                  │  (Port 3000)│
                  └──┬───┬───┬──┘
                     │   │   │
          ┌──────────┘   │   └──────────┐
          ▼              ▼              ▼
   ┌─────────────┐ ┌─────────┐ ┌──────────────┐
   │ Prometheus  │ │  Loki   │ │ Alertmanager │
   │  (Port 9090)│ │ (:3100) │ │  (Port 9093) │
   └──────┬──────┘ └────┬────┘ └──────┬───────┘
          │              │              │
    ┌─────┼─────┐   ┌───┘         ┌────┘
    ▼     ▼     ▼   ▼             ▼
  cAdvisor Node  Promtail      ntfy (:80)
          Exporter              → push notifications
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Prometheus | `prom/prometheus:v2.54.1` | 9090 | Metrics collection & alerting rules |
| Grafana | `grafana/grafana:11.2.0` | 3000 | Dashboards & visualization |
| Loki | `grafana/loki:3.2.0` | 3100 (internal) | Log aggregation |
| Promtail | `grafana/promtail:3.2.0` | — | Log collection agent |
| Alertmanager | `prom/alertmanager:v0.27.0` | 9093 | Alert routing to ntfy |
| cAdvisor | `gcr.io/cadvisor/cadvisor:v0.49.1` | 8080 (internal) | Container metrics |
| Node Exporter | `prom/node-exporter:v1.8.2` | 9100 (internal) | Host metrics |
| Uptime Kuma | `louislam/uptime-kuma:1.23.15` | 3001 | Service availability monitoring |

## Quick Start

```bash
# 1. Copy and configure
cp .env.example .env
nano .env

# 2. Start the stack
docker compose up -d

# 3. Verify
docker compose ps
curl -s http://localhost:9090/-/healthy
curl -s http://localhost:3000/api/health

# 4. (Optional) Setup Uptime Kuma monitors
../../scripts/uptime-kuma-setup.sh
```

## Prometheus Scrape Targets

Configured in `config/prometheus/prometheus.yml`:

| Job | Target | Purpose |
|-----|--------|---------|
| prometheus | localhost:9090 | Self-monitoring |
| node-exporter | node-exporter:9100 | Host CPU/memory/disk/network |
| cadvisor | cadvisor:8080 | Container resource usage |
| traefik | traefik:8080 | Reverse proxy metrics |
| loki | loki:3100 | Log system metrics |

## Alert Rules

Located in `config/prometheus/rules/homelab.yml`:

**Host alerts:**
- CPU > 80% for 5 minutes
- Memory > 90%
- Disk usage > 85%
- Disk IO saturation

**Container alerts:**
- Container down
- Container restarting > 3 times/hour
- Container OOM killed
- Container health check failing

**Service alerts:**
- Traefik 5xx error rate > 1%
- Service P99 response time > 2s

All alerts route to ntfy for push notifications.

## Grafana Dashboards

Auto-provisioned (no manual import needed):

| Dashboard | Source |
|-----------|--------|
| HomeLab Overview | `config/grafana/dashboards/homelab-overview.json` |

Additional dashboards can be imported from Grafana.com:
- Node Exporter Full: ID 1860
- Docker Container & Host Metrics: ID 179
- Traefik Official: ID 17346

## Grafana Auth (Authentik SSO)

Grafana is pre-configured for Authentik OIDC. Groups mapping:
- `homelab-admins` → Admin role
- `homelab-users` → Viewer role

## Uptime Kuma

Access at `https://status.DOMAIN`. Run `scripts/uptime-kuma-setup.sh` for initial setup guidance.

Status page can be made public for dashboard access without login.

## Log Queries (Loki)

In Grafana → Explore → Loki:

```logql
# All container logs
{job="docker"}

# Specific container
{container_name="traefik"}

# Error logs only
{container_name=~".+"} |= "error"

# Traefik access logs with 5xx
{container_name="traefik"} |= "HTTP/2.0\" 5"
```

## Data Retention

| System | Default | Configure |
|--------|---------|-----------|
| Prometheus | 30d | `--storage.tsdb.retention.time` in compose |
| Loki | 7d | `config/loki/loki-config.yml` |
| Grafana | indefinite | grafana_data volume |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Prometheus targets down | Check if target container is on `monitoring` network |
| Grafana no data | Verify datasource URL matches internal service name |
| No logs in Loki | Check Promtail container logs, verify Docker socket mounted |
| Alerts not firing | Run `promtool check rules /etc/prometheus/rules/*.yml` |
| Uptime Kuma unreachable | Check Traefik labels, verify proxy network connection |
