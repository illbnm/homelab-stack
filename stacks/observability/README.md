# Observability Stack — Prometheus + Grafana + Loki + Tempo + Alerting + Uptime

Full observability covering **Metrics / Logs / Traces / Alerting / SLA monitoring** — the three pillars of observability plus uptime monitoring.

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │              Grafana :3000               │
                    │   Dashboards / Explore / OnCall / OIDC  │
                    └──┬──────────┬──────────┬────────────────┘
                       │          │          │
            ┌──────────┘    ┌─────┘    ┌─────┘
            ▼               ▼          ▼
     ┌─────────────┐ ┌──────────┐ ┌─────────┐
     │ Prometheus   │ │  Loki    │ │  Tempo  │
     │ :9090        │ │ :3100    │ │ :3200   │
     │ (Metrics)    │ │ (Logs)   │ │(Traces) │
     └──┬───┬───┬───┘ └────┬────┘ └────┬────┘
        │   │   │          │            │
        │   │   │          │            │
   ┌────┘   │   └────┐     │      OTLP/gRPC
   ▼        ▼        ▼     ▼      :4317/:4318
┌───────┐┌──────┐┌──────┐┌─────────┐
│ Node  ││cAd-  ││Trae- ││Promtail │
│Export.││visor ││fik   ││(Agent)  │
│ :9100 ││:8080 ││:8080 ││         │
└───────┘└──────┘└──────┘└─────────┘

                    ┌───────────────┐
                    │ Alertmanager  │──▶ ntfy push
                    │    :9093      │
                    └───────────────┘

    ┌──────────────┐     ┌──────────────┐
    │ Uptime Kuma  │     │  OnCall      │
    │  :3001       │     │  :8080       │
    │ (SLA/Status) │     │ (Incidents)  │
    └──────────────┘     └──────────────┘
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Prometheus | `prom/prometheus:v2.54.1` | 9090 | Metrics collection & alerting rules |
| Grafana | `grafana/grafana:11.2.2` | 3000 | Dashboards, Explore, OnCall UI |
| Loki | `grafana/loki:3.2.0` | 3100 | Log aggregation & querying |
| Promtail | `grafana/promtail:3.2.0` | 9080 | Log collection agent |
| Tempo | `grafana/tempo:2.6.0` | 3200 | Distributed tracing backend |
| Alertmanager | `prom/alertmanager:v0.27.0` | 9093 | Alert routing & ntfy push |
| cAdvisor | `gcr.io/cadvisor/cadvisor:v0.50.0` | 8080 | Container resource metrics |
| Node Exporter | `prom/node-exporter:v1.8.2` | 9100 | Host/system metrics |
| Uptime Kuma | `louislam/uptime-kuma:1.23.15` | 3001 | SLA monitoring & status page |
| Grafana OnCall | `grafana/oncall:v1.9.22` | 8080 | Incident & on-call management |

## Prerequisites

- Base stack running (`stacks/base/` — Traefik + proxy network)
- Domain with DNS pointing to your server
- ntfy stack running (for alert notifications) — `stacks/notifications/`

## Quick Start

```bash
# 1. Copy and fill environment variables
cp .env.example .env
nano .env  # Fill DOMAIN, Authentik OIDC creds, ntfy settings

# 2. Start the stack
docker compose up -d

# 3. Wait for all services to be healthy
docker compose ps

# 4. Access Grafana
open https://grafana.${DOMAIN}

# 5. (Optional) Setup Uptime Kuma monitors
chmod +x scripts/uptime-kuma-setup.sh
./scripts/uptime-kuma-setup.sh
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | YES | `localhost` | Your homelab domain |
| `GRAFANA_ADMIN_USER` | NO | `admin` | Grafana admin username |
| `GRAFANA_ADMIN_PASSWORD` | YES | `changeme` | Grafana admin password |
| `AUTHENTIK_DOMAIN` | YES | — | Authentik domain for OIDC |
| `GRAFANA_OAUTH_CLIENT_ID` | YES | — | Authentik OIDC client ID |
| `GRAFANA_OAUTH_CLIENT_SECRET` | YES | — | Authentik OIDC client secret |
| `PROMETHEUS_RETENTION` | NO | `30d` | Prometheus data retention |
| `LOKI_RETENTION` | NO | `7d` | Loki log retention |
| `TEMPO_RETENTION` | NO | `72h` | Tempo trace retention |
| `NTFY_URL` | NO | `http://ntfy:80` | ntfy server URL |
| `NTFY_TOPIC` | NO | `homelab-alerts` | ntfy notification topic |
| `NTFY_TOKEN` | NO | — | ntfy auth token (optional) |
| `ONCALL_SECRET_KEY` | YES | — | Grafana OnCall secret key |

## Pre-provisioned Dashboards

All dashboards are auto-loaded via Grafana provisioning (no manual import needed):

| Dashboard | Grafana ID | Description |
|-----------|------------|-------------|
| Node Exporter Full | 1860 | Host CPU, memory, disk, network |
| Docker Container & Host Metrics | 179 | Container resources & health |
| Traefik Official | 17346 | Reverse proxy requests, latency, errors |
| Loki Dashboard | 13639 | Log ingestion, query performance, live logs |
| Uptime Kuma | 18278 | Service availability & SLA |
| Logs Explorer | — | Quick access to all container & Traefik logs |

## Alert Rules

Three alert rule groups cover host, container, and service health:

### Host Alerts (`configs/prometheus/alerts/host.yml`)
- CPU > 80% for 5 min
- Memory > 90% for 5 min
- Disk > 85% for 5 min
- Disk I/O saturation > 90%
- Network errors
- System load

### Container Alerts (`configs/prometheus/alerts/containers.yml`)
- Container restart loop (>3/hour)
- Container OOM killed
- Container unhealthy (health check failing)
- Container high CPU/memory
- Container not running

### Service Alerts (`configs/prometheus/alerts/services.yml`)
- Traefik 5xx error rate > 1%
- Service response time P99 > 2s
- Prometheus target down
- Loki ingestion rate drop
- High number of firing alerts

All alerts route to **Alertmanager → ntfy** for push notifications.

## Prometheus Scrape Targets

| Job | Target | Metrics Path |
|-----|--------|-------------|
| `prometheus` | `localhost:9090` | `/metrics` |
| `node-exporter` | `node-exporter:9100` | `/metrics` |
| `cadvisor` | `cadvisor:8080` | `/metrics` |
| `traefik` | `traefik:8080` | `/metrics` |
| `authentik` | `authentik-server:9300` | `/metrics/performance` |
| `nextcloud` | `nextcloud:9117` | `/metrics` |
| `gitea` | `gitea:3000` | `/metrics` |
| `loki` | `loki:3100` | `/metrics` |
| `tempo` | `tempo:3200` | `/metrics` |
| `alertmanager` | `alertmanager:9093` | `/metrics` |
| `grafana` | `grafana:3000` | `/metrics` |
| `uptime-kuma` | `uptime-kuma:3001` | `/metrics` |

## Grafana OIDC (Authentik)

The stack integrates Authentik for SSO login:

- `homelab-admins` group → Grafana **Admin** role
- `homelab-users` group → Grafana **Viewer** role
- Auto-redirect to Authentik login page
- Sign-out redirects back to Authentik

## Log Collection (Promtail → Loki)

Promtail auto-discovers all Docker containers and collects:

- **All container logs** (stdout/stderr, JSON parsing)
- **System logs** (`/var/log/syslog`, `/var/log/auth.log`)
- **Traefik access logs** (parsed CLF format with status codes)

Access logs via Grafana → Explore → Loki, or the pre-built Logs Explorer dashboard.

## Distributed Tracing (Tempo)

Tempo receives traces via:
- **OTLP gRPC**: port 4317
- **OTLP HTTP**: port 4318
- **Zipkin**: port 9411

Grafana is pre-configured with trace-to-log and trace-to-metric correlations.

## Data Retention

| Store | Default | Configurable via |
|-------|---------|-----------------|
| Prometheus | 30 days | `PROMETHEUS_RETENTION` |
| Loki | 7 days | `LOKI_RETENTION` |
| Tempo | 72 hours | `TEMPO_RETENTION` |

## Uptime Kuma

After setup, configure at `https://status.${DOMAIN}`:
1. Create admin account
2. Add monitors for all homelab services
3. Create a public status page (slug: `/`)
4. Configure ntfy notifications

Run `./scripts/uptime-kuma-setup.sh` for guided setup.

## Health Check

```bash
# All containers healthy
docker compose ps

# Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Loki ready
curl -sf http://localhost:3100/ready && echo OK

# Tempo ready
curl -sf http://localhost:3200/ready && echo OK

# Grafana health
curl -sf http://localhost:3000/api/health && echo OK

# Alertmanager healthy
curl -sf http://localhost:9093/-/healthy && echo OK
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Grafana shows "No data" for all panels | Check Prometheus is scraping targets: `curl localhost:9090/api/v1/targets` |
| Loki shows no logs | Check Promtail is running: `docker logs promtail`; verify Docker socket is mounted |
| Alerts not firing | Verify alert rules: `docker exec prometheus promtool check rules /etc/prometheus/alerts/*.yml` |
| ntfy not receiving alerts | Check Alertmanager config: `curl localhost:9093/api/v2/alerts`; verify ntfy URL |
| Grafana OIDC login fails | Verify `GRAFANA_OAUTH_CLIENT_ID/SECRET` match Authentik provider settings |
| Dashboard JSON not loading | Check provisioning: `docker exec grafana ls /var/lib/grafana/dashboards/` |
| Tempo not receiving traces | Verify OTLP endpoint: `curl -X POST http://localhost:4318/v1/traces` |

## CN Mirror

If `gcr.io` or `grafana.com` is inaccessible, edit `docker-compose.yml` and swap images to CN mirrors:

```yaml
# cadvisor
image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/gcr.io/cadvisor/cadvisor:v0.50.0
```

See `../../scripts/cn-pull.sh` for automated image pulling.
