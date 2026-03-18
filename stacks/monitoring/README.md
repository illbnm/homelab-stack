# 📊 Observability Stack

Complete observability covering the **three pillars** (Metrics, Logs, Traces) plus Alerting, Uptime monitoring, and On-Call management.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Grafana (Visualization)                      │
│                    grafana.${DOMAIN} — Authentik SSO                │
│          ┌──────────┬──────────┬──────────┬──────────────┐          │
│          │ Dashboards│ Explore  │ Alerting │  OnCall      │          │
│          └────┬─────┴────┬─────┴────┬─────┴──────┬───────┘          │
│               │          │          │            │                   │
├───────────────┼──────────┼──────────┼────────────┼───────────────────┤
│               ▼          ▼          ▼            ▼                   │
│         ┌──────────┐┌──────────┐┌──────────┐┌──────────────┐        │
│         │Prometheus││   Loki   ││  Tempo   ││Grafana OnCall│        │
│         │ Metrics  ││   Logs   ││ Traces   ││  Incidents   │        │
│         └────┬─────┘└────┬─────┘└──────────┘└──────────────┘        │
│              │           │                                           │
│     ┌────────┼───────┐   │                                           │
│     ▼        ▼       ▼   ▼                                           │
│ ┌────────┐┌──────┐┌─────────┐                                       │
│ │cAdvisor││ Node ││Promtail │                                       │
│ │        ││Export││         │                                       │
│ └────────┘└──────┘└─────────┘                                       │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐                                  │
│  │ Alertmanager │  │ Uptime Kuma  │                                  │
│  │   → ntfy     │  │ status.${D}  │                                  │
│  └──────────────┘  └──────────────┘                                  │
└─────────────────────────────────────────────────────────────────────┘
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Prometheus | `prom/prometheus:v2.54.1` | 9090 | Metrics collection & storage |
| Grafana | `grafana/grafana:11.2.2` | 3000 | Visualization & dashboards |
| Loki | `grafana/loki:3.2.0` | 3100 | Log aggregation |
| Promtail | `grafana/promtail:3.2.0` | 9080 | Log collection agent |
| Tempo | `grafana/tempo:2.6.0` | 3200 | Distributed tracing |
| Alertmanager | `prom/alertmanager:v0.27.0` | 9093 | Alert routing → ntfy |
| cAdvisor | `gcr.io/cadvisor/cadvisor:v0.50.0` | 8080 | Container metrics |
| Node Exporter | `prom/node-exporter:v1.8.2` | 9100 | Host system metrics |
| Uptime Kuma | `louislam/uptime-kuma:1.23.15` | 3001 | Service availability monitoring |
| Grafana OnCall | `grafana/oncall:v1.9.22` | 8080 | On-call & incident management |

## Prerequisites

| Requirement | Purpose |
|-------------|---------|
| Base infrastructure stack running | Traefik reverse proxy + DNS |
| SSO stack running (optional) | Authentik for Grafana OIDC |
| Notifications stack running (optional) | ntfy for alert delivery |

## Quick Start

```bash
# 1. Copy environment file
cp .env.example .env
# Edit .env with your domain and credentials

# 2. Download Grafana dashboards (one-time)
docker compose run --rm grafana-dashboards-init

# 3. Start the stack
docker compose up -d

# 4. Set up Uptime Kuma monitors
chmod +x ../../scripts/uptime-kuma-setup.sh
../../scripts/uptime-kuma-setup.sh yourdomain.com admin yourpassword

# 5. Verify
# Grafana:      https://grafana.yourdomain.com
# Prometheus:   https://prometheus.yourdomain.com/targets
# Alertmanager: https://alertmanager.yourdomain.com
# Status page:  https://status.yourdomain.com
```

## Configuration Details

### 1. Prometheus Scrape Targets

All targets are configured in `config/prometheus/prometheus.yml`:

| Job | Target | Purpose |
|-----|--------|---------|
| `prometheus` | `localhost:9090` | Self-monitoring |
| `node-exporter` | `node-exporter:9100` | Host CPU, memory, disk, network |
| `cadvisor` | `cadvisor:8080` | Container resource metrics |
| `traefik` | `traefik:8080` | Reverse proxy metrics |
| `authentik` | `authentik-server:9300` | SSO metrics |
| `nextcloud` | `nextcloud:9205` | Storage metrics |
| `gitea` | `gitea:3000` | Git hosting metrics |
| `loki` | `loki:3100` | Log aggregation self-monitoring |
| `tempo` | `tempo:3200` | Tracing self-monitoring |
| `grafana` | `grafana:3000` | Dashboard self-monitoring |

Verify all targets: `https://prometheus.yourdomain.com/targets`

### 2. Grafana Dashboards (Auto-Provisioned)

Dashboards are automatically downloaded from Grafana.com and provisioned:

| Dashboard | Grafana ID | Description |
|-----------|-----------|-------------|
| Node Exporter Full | 1860 | Complete host metrics |
| Docker Container & Host | 179 | Container resource usage |
| Traefik Official | 17346 | Reverse proxy traffic |
| Loki Dashboard | 13639 | Log query & analysis |
| Uptime Kuma | 18278 | Service availability |

To re-download dashboards:
```bash
docker compose run --rm grafana-dashboards-init
```

### 3. Alert Rules

Alert rules are split into three files under `config/prometheus/alerts/`:

#### `host.yml` — Host-Level Alerts
| Alert | Condition | Severity |
|-------|-----------|----------|
| HostHighCPU | CPU > 80% for 5min | warning |
| HostCriticalCPU | CPU > 95% for 2min | critical |
| HostHighMemory | Memory > 90% for 5min | critical |
| HostDiskSpaceLow | Disk < 15% free | warning |
| HostDiskSpaceCritical | Disk < 5% free | critical |
| HostDiskIOHigh | IO saturation > 90% for 10min | warning |
| HostOOMKillDetected | OOM kill event | critical |

#### `containers.yml` — Container Alerts
| Alert | Condition | Severity |
|-------|-----------|----------|
| ContainerHighRestartRate | > 3 restarts/hour | warning |
| ContainerOOMKilled | OOM kill event | critical |
| ContainerDown | Not seen for 2min | warning |
| ContainerCPUThrottling | Throttled > 0.5s/s for 10min | warning |
| ContainerHighMemory | > 90% of memory limit | warning |

#### `services.yml` — Service & Application Alerts
| Alert | Condition | Severity |
|-------|-----------|----------|
| TraefikHighErrorRate | 5xx rate > 1% for 5min | critical |
| TraefikServiceDown | Backend unreachable | critical |
| ServiceHighLatencyP99 | P99 > 2s for 5min | warning |
| PrometheusTargetDown | Scrape target down for 5min | critical |

All alerts route to Alertmanager → ntfy for push notifications.

**Test alerting:**
```bash
# Trigger CPU alert
stress --cpu 4 --timeout 360
# → ntfy notification within 5 minutes
```

### 4. Log Collection (Promtail → Loki)

Promtail automatically collects:
- **Docker container logs** — auto-discovered via Docker socket
- **System logs** — `/var/log/syslog`
- **Traefik access logs** — JSON-parsed with status, method, service labels

Access via Grafana: `https://grafana.yourdomain.com/explore` → select Loki datasource

Quick link for logs: `/d/logs/logs`

### 5. Distributed Tracing (Tempo)

Tempo accepts traces via:
- **OTLP gRPC**: `tempo:4317`
- **OTLP HTTP**: `tempo:4318`
- **Zipkin**: `tempo:9411`

Grafana automatically links:
- Traces → Logs (via Loki)
- Traces → Metrics (via Prometheus)
- Service map visualization

### 6. Uptime Kuma

Public status page: `https://status.yourdomain.com`

Auto-setup script creates monitors for all deployed services:
```bash
./scripts/uptime-kuma-setup.sh yourdomain.com
```

Notifications are sent to ntfy on service downtime.

### 7. Grafana Authentication (Authentik OIDC)

| Authentik Group | Grafana Role |
|----------------|-------------|
| `homelab-admins` | Admin |
| `homelab-users` | Viewer |

**Authentik setup:**
1. Create an OAuth2/OIDC Provider for Grafana
2. Set redirect URI: `https://grafana.yourdomain.com/login/generic_oauth`
3. Copy Client ID and Secret to `.env`
4. Create `homelab-admins` and `homelab-users` groups
5. Assign users to appropriate groups

### 8. Data Retention

| Data Type | Default Retention | Config Variable |
|-----------|-------------------|-----------------|
| Metrics (Prometheus) | 30 days | `PROMETHEUS_RETENTION` |
| Logs (Loki) | 7 days | `LOKI_RETENTION` |
| Traces (Tempo) | 3 days | `TEMPO_RETENTION` |

## Subdomains

| Subdomain | Service |
|-----------|---------|
| `grafana.${DOMAIN}` | Grafana dashboards |
| `prometheus.${DOMAIN}` | Prometheus UI (auth-protected) |
| `alertmanager.${DOMAIN}` | Alertmanager UI (auth-protected) |
| `status.${DOMAIN}` | Uptime Kuma (public) |
| `oncall.${DOMAIN}` | Grafana OnCall (auth-protected) |

## Volumes

| Volume | Purpose | Backup Priority |
|--------|---------|-----------------|
| `prometheus_data` | Metrics TSDB | Medium |
| `grafana_data` | Grafana config & state | High |
| `loki_data` | Log storage | Low |
| `alertmanager_data` | Alert silences & state | Medium |
| `tempo_data` | Trace storage | Low |
| `uptime_kuma_data` | Monitor config & history | High |
| `oncall_data` | Incident history | Medium |

## Troubleshooting

### Prometheus targets showing DOWN
```bash
# Check target connectivity from Prometheus container
docker exec prometheus wget -q --spider http://TARGET:PORT/-/healthy

# Reload Prometheus config
curl -X POST http://localhost:9090/-/reload
```

### Grafana dashboards not loading
```bash
# Re-download dashboards
docker compose run --rm grafana-dashboards-init

# Check provisioning logs
docker logs grafana 2>&1 | grep -i "provisioning\|dashboard"
```

### Loki not receiving logs
```bash
# Check Promtail status
docker logs promtail --tail 50

# Verify Loki is ready
curl http://localhost:3100/ready

# Test log ingestion
docker logs loki 2>&1 | grep -i "error\|warn"
```

### Alerts not firing
```bash
# Check Prometheus rules
docker exec prometheus promtool check rules /etc/prometheus/rules/*.yml

# Check Alertmanager config
docker exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml

# List active alerts
curl http://localhost:9093/api/v2/alerts | jq
```

### Uptime Kuma not accessible
```bash
# Check container health
docker inspect uptime-kuma --format='{{.State.Health.Status}}'

# View logs
docker logs uptime-kuma --tail 50
```
