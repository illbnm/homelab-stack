# Observability Stack — Complete Monitoring Solution

Provides comprehensive observability for all HomeLab services via Prometheus (metrics), Grafana (dashboards), Loki (logs), Tempo (tracing), and Uptime Kuma (availability).

## Architecture

```
                                    ┌─────────────────┐
                                    │    Grafana      │
                                    │  (Dashboards)   │
                                    └────────┬────────┘
                                             │
         ┌───────────────────────────────────┼───────────────────────────────────┐
         │                                   │                                   │
         ▼                                   ▼                                   ▼
┌─────────────────┐              ┌─────────────────┐              ┌─────────────────┐
│   Prometheus    │              │      Loki       │              │     Tempo       │
│   (Metrics)     │              │    (Logs)       │              │   (Tracing)     │
└────────┬────────┘              └────────┬────────┘              └────────┬────────┘
         │                                │                                │
         │         ┌──────────────────────┼──────────────────────┐         │
         │         │                      │                      │         │
         ▼         ▼                      ▼                      ▼         ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              HomeLab Services                                    │
│  Traefik │ Authentik │ Gitea │ Nextcloud │ Grafana │ Prometheus │ etc...       │
└─────────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐              ┌─────────────────┐
│ cAdvisor        │              │ Node Exporter   │
│ (Container)     │              │ (Host)          │
└─────────────────┘              └─────────────────┘
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| prometheus | `prom/prometheus:v2.54.1` | 9090 | Metrics collection & alerting |
| grafana | `grafana/grafana:11.2.2` | 3000 | Visualization dashboards |
| loki | `grafana/loki:3.2.0` | 3100 | Log aggregation |
| promtail | `grafana/promtail:3.2.0` | — | Log collection agent |
| tempo | `grafana/tempo:2.6.0` | 3200 | Distributed tracing |
| alertmanager | `prom/alertmanager:v0.27.0` | 9093 | Alert routing & notification |
| cadvisor | `gcr.io/cadvisor/cadvisor:v0.50.0` | 8080 | Container resource metrics |
| node-exporter | `prom/node-exporter:v1.8.2` | 9100 | Host resource metrics |
| uptime-kuma | `louislam/uptime-kuma:1.23.15` | 3001 | Service availability monitoring |

## Prerequisites

- Base stack running (`stacks/base/` — Traefik + proxy network)
- Domain with DNS pointing to your server
- Ports 80 + 443 open
- Authentik SSO stack running (for Grafana OAuth)

## Quick Start

```bash
# 1. Copy and fill environment variables
cd stacks/monitoring
cp .env.example .env
nano .env  # Fill ALL values

# 2. Generate secure passwords
export GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32)
sed -i "s|^GRAFANA_ADMIN_PASSWORD=.*|GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD|" .env

# 3. Start the stack
docker compose up -d

# 4. Wait for all services to be healthy
docker compose ps

# 5. Run Uptime Kuma setup
../../scripts/uptime-kuma-setup.sh
```

## Access URLs

| Service | URL | Auth |
|---------|-----|------|
| Grafana | `https://grafana.${DOMAIN}` | Authentik OIDC |
| Prometheus | `https://prometheus.${DOMAIN}` | Authentik ForwardAuth |
| Alertmanager | `https://alertmanager.${DOMAIN}` | Authentik ForwardAuth |
| Uptime Kuma | `https://status.${DOMAIN}` | Public (status page) |

## Pre-configured Dashboards

Grafana automatically loads these dashboards:

| Dashboard | Description | Location |
|-----------|-------------|----------|
| Node Exporter Full | Host CPU, memory, disk, network | `/d/node-exporter-full` |
| Docker Container Metrics | Container resource usage | `/d/docker-containers` |
| Loki Dashboard | Log volume and error logs | `/d/loki-dashboard` |
| Uptime Kuma | Service availability status | `/d/uptime-kuma` |

## Alert Rules

### Host Alerts (`config/prometheus/rules/host.yml`)
- CPU > 80% for 5m → Warning
- CPU > 95% for 2m → Critical
- Memory > 90% for 5m → Warning
- Memory > 95% for 2m → Critical
- Disk > 85% → Warning
- Disk > 95% → Critical

### Container Alerts (`config/prometheus/rules/containers.yml`)
- Container restart rate > 3/hour
- Container OOM killed
- Container health check failed
- Container CPU > 80%
- Container Memory > 90%

### Service Alerts (`config/prometheus/rules/services.yml`)
- Traefik 5xx error rate > 1%
- Service response time P99 > 2s
- Service down
- Prometheus target down

## Alert Notifications

All alerts are routed to **ntfy** for push notifications:

- **Normal alerts** → `homelab-alerts` topic
- **Critical alerts** → `homelab-critical` topic (immediate)

Subscribe to notifications:
```bash
# On your phone or desktop
ntfy subscribe homelab-alerts
ntfy subscribe homelab-critical
```

## Log Collection

Promtail automatically collects logs from:
- All Docker containers (auto-discovery via Docker socket)
- System logs (`/var/log/syslog`)
- Traefik access logs
- Docker daemon logs
- Authentication logs

Query logs in Grafana:
1. Go to **Explore** → Select **Loki** datasource
2. Use query: `{container="traefik"}` or `{job="syslog"}`
3. Filter by severity: `{container="traefik"} |= "error"`

## Tracing

Tempo provides distributed tracing with:
- Jaeger thrift HTTP receiver
- Zipkin receiver
- OTLP receiver (HTTP + gRPC)

Configure your application to send traces to `http://tempo:3200`.

## Uptime Kuma Setup

Run the auto-setup script to create monitors for all services:

```bash
../../scripts/uptime-kuma-setup.sh
```

This creates monitors for:
- Traefik
- Grafana
- Prometheus
- Loki
- Alertmanager
- Authentik
- Gitea
- Nextcloud

## Grafana OIDC Integration

Grafana is pre-configured to use Authentik for authentication:

1. In Authentik, create an OAuth2 Provider for Grafana:
   - Name: Grafana
   - Redirect URI: `https://grafana.${DOMAIN}/login/generic_oauth`

2. Get Client ID and Secret from Authentik

3. Update `.env`:
   ```bash
   GRAFANA_OAUTH_CLIENT_ID=your-client-id
   GRAFANA_OAUTH_CLIENT_SECRET=your-client-secret
   ```

4. Restart Grafana:
   ```bash
   docker compose restart grafana
   ```

5. In Authentik, assign users to groups:
   - `homelab-admins` → Grafana Admin role
   - `homelab-users` → Grafana Editor role

## Data Retention

| Service | Retention | Config |
|---------|-----------|--------|
| Prometheus | 30 days | `PROMETHEUS_RETENTION` |
| Loki | 7 days | `LOKI_RETENTION` |
| Tempo | 3 days | `TEMPO_RETENTION` |

## Health Check

```bash
# All containers healthy
docker compose ps

# Prometheus healthy
curl -sf https://prometheus.${DOMAIN}/-/healthy && echo OK

# Grafana healthy
curl -sf https://grafana.${DOMAIN}/api/health && echo OK

# Loki ready
curl -sf http://loki:3100/ready && echo OK

# Tempo ready
curl -sf http://tempo:3200/ready && echo OK

# Alertmanager healthy
curl -sf http://alertmanager:9093/-/healthy && echo OK
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Prometheus targets down | Check network connectivity; ensure services are running |
| Grafana login fails | Verify OIDC configuration in Authentik and `.env` |
| No logs in Loki | Check Promtail configuration; ensure Docker socket is mounted |
| Alerts not sending | Verify ntfy topic; check Alertmanager configuration |
| High memory usage | Reduce retention periods; increase scrape interval |

## CN Mirror

If Docker Hub is inaccessible, edit `docker-compose.yml` and use CN mirrors:

```yaml
# Example for Grafana
image: swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/grafana/grafana:11.2.2
```

## Next Steps

1. Customize alert thresholds in `config/prometheus/rules/*.yml`
2. Create custom dashboards in Grafana
3. Set up additional notification channels (email, Slack, etc.)
4. Configure log retention policies
5. Add application-specific metrics exporters

---

**Bounty**: #10 — Observability Stack ($280 USDT)
**Wallet**: TMLkvEDrjvHEUbWYU1jfqyUKmbLNZkx6T1 (USDT TRC20)
