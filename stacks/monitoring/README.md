# Observability Stack

Full metrics / logs / alerting / uptime monitoring for HomeLab Stack.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Prometheus | 2.54 | `prometheus.<DOMAIN>` | Metrics collection & alerting |
| Grafana | 11.2 | `grafana.<DOMAIN>` | Visualization & dashboards |
| Loki | 3.2 | — | Log aggregation |
| Promtail | 3.2 | — | Log collection agent |
| Alertmanager | 0.27 | — | Alert routing & notification |
| cAdvisor | 0.50 | — | Container resource metrics |
| Node Exporter | 1.8 | — | Host metrics (CPU, disk, network) |
| Grafana OnCall | 1.9 | `oncall.<DOMAIN>` | On-call alert management |
| Uptime Kuma | 1.23 | `status.<DOMAIN>` | Service availability monitoring |

## Architecture

```
stacks/base (proxy network)
    │
    ├──► Prometheus ─── scrape ──► cAdvisor (container metrics)
    │         │                     Node Exporter (host metrics)
    │         │                     Traefik (proxy metrics)
    │         │                     Loki (log metrics)
    │         │                     Uptime Kuma (SLA metrics)
    │         │
    │         └── alerting ──► Alertmanager ──► ntfy
    │
    ├──► Grafana ─── dashboards: Node Exporter Full, Docker, Traefik, Loki, UptimeKuma
    │
    ├──► Loki ◄── Promtail ◄── Docker containers + system logs
    │
    └──► Uptime Kuma ── public status page: status.<DOMAIN>
```

## Prerequisites

- HomeLab Stack **base infrastructure** already deployed (`stacks/base`)
- `proxy` network must exist: `docker network create proxy`
- Authentik SSO configured (for Grafana OAuth login)

## Quick Start

```bash
cd stacks/monitoring
cp .env.example .env    # edit with your values
docker compose up -d
```

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain, e.g. `home.example.com` |
| `GRAFANA_ADMIN_PASSWORD` | ✅ | Initial Grafana admin password |
| `AUTHENTIK_DOMAIN` | ✅ | Authentik domain for SSO |
| `GRAFANA_OAUTH_CLIENT_ID` | ✅ | OAuth2 Client ID from Authentik |
| `GRAFANA_OAUTH_CLIENT_SECRET` | ✅ | OAuth2 Client Secret |
| `PROMETHEUS_RETENTION` | — | Prometheus data retention (default: `30d`) |
| `LOKI_RETENTION` | — | Loki log retention (default: `7d`) |
| `NTFY_WEBHOOK_URL` | — | ntfy webhook URL for alerts |
| `TZ` | — | Timezone (default: `Asia/Shanghai`) |

### Authentik OAuth Setup

1. In Authentik admin UI: **Applications → Applications → Create**
2. Set name: `Grafana`, slug: `grafana`
3. Provider: Create OAuth2/OpenID Provider:
   - Name: `grafana`
   - Redirect URIs: `https://grafana.yourdomain.com/login/generic_oauth`
   - Signing Key: create new
4. In the created provider, copy **Client ID** and **Client Secret**
5. In Authentik: **Users → Groups → Create** groups `homelab-admins` and `homelab-users`
6. Assign users to appropriate groups
7. Set `GRAFANA_OAUTH_CLIENT_ID` and `GRAFANA_OAUTH_CLIENT_SECRET` in `.env`

## Dashboards

All dashboards are auto-provisioned on startup (no manual import needed):

| Dashboard | UID | Purpose |
|-----------|-----|---------|
| Node Exporter Full | `node-exporter-full` | Host CPU, memory, disk, network |
| Docker Container & Host Metrics | `docker-host-metrics` | Container resource usage |
| Traefik Official | `traefik-official` | Request rate, latency, errors |
| Loki Dashboard | `loki-dashboard` | Log explorer + Loki metrics |
| Uptime Kuma | `uptime-kuma` | SLA monitoring |

## Alert Rules

Located in `config/prometheus/rules/`:

| File | Category | What it watches |
|------|----------|-----------------|
| `host.yml` | Host | CPU > 80%, Memory > 90%, Disk > 85%, Disk I/O |
| `containers.yml` | Container | Restarts > 3/hr, OOM kills, health check failures |
| `services.yml` | Service | Traefik 5xx > 1%, P99 latency > 2s |

All alerts route through Alertmanager → ntfy (or configured webhook).

## Grafana OnCall

Grafana OnCall provides on-call scheduling and alert routing:

- URL: `https://oncall.<DOMAIN>`
- First-run setup: navigate to the URL and create an admin account
- Connects to Alertmanager for alert routing
- Integrates with Slack, PagerDuty, VictorOps (configure in OnCall settings)

## Uptime Kuma

Public status page for SLA monitoring:

- URL: `https://status.<DOMAIN>` (no login required)
- Auto-discovers and monitors all Traefik-routed services
-宕机通知通过 ntfy 推送
- Run `scripts/uptime-kuma-setup.sh` to auto-populate monitor targets

### Uptime Kuma Setup Script

```bash
# After starting the monitoring stack, run:
./scripts/uptime-kuma-setup.sh
```

This creates monitors for all deployed services by querying the Traefik API.

## Alert Notifications

Alerts flow through this chain:

```
Prometheus → Alertmanager → ntfy → push notification
```

### Configuring ntfy

If running ntfy locally (via `stacks/notifications`):

```bash
# In .env:
NTFY_WEBHOOK_URL=http://ntfy:80/t/homelab-alerts
```

For external ntfy.sh:

```bash
NTFY_WEBHOOK_URL=https://ntfy.sh/YOUR_TOPIC_ID
```

## Troubleshooting

**Prometheus targets show DOWN:**
- Check if the target service is running: `docker ps`
- Check network connectivity: services must be on `monitoring` network
- Verify cAdvisor and node-exporter are running

**Grafana dashboards show "No data":**
- Wait 1-2 minutes for first scrape cycle to complete
- Check Prometheus targets: `https://prometheus.<DOMAIN>/targets`
- Verify datasource UID matches: `prometheus` in datasource config

**Alertmanager not receiving alerts:**
- Check `config/alertmanager/alertmanager.yml` is valid: `docker exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml`
- Verify `NTFY_WEBHOOK_URL` is reachable from the container

**Uptime Kuma status page shows "No data":**
- Uptime Kuma polls services directly (not via Prometheus)
- Ensure services expose HTTP endpoints on the `monitoring` network
