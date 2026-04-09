# Monitoring Stack — Observability for HomeLab

Full observability stack: **Metrics** + **Logs** + **Traces** + **Alerting** + **Uptime Monitoring**.

## Architecture

```
                    +----------+    +-----------+
                    | Grafana  |    | Alertmgr  |
                    | :3000    |    | :9093     |
                    +----+-----+    +-----+-----+
                         |               |
          +--------------+---------------+------------+
          |              |               |            |
    +-----+----+   +-----+----+   +------+------+   +---------+
    |Prometheus|   |  Loki    |   |   Tempo     |   |Uptime   |
    | :9090    |   |  :3100   |   |   :3200     |   |Kuma     |
    +-----+----+   +-----+----+   +------+------+   | :3001   |
          |              |               |            +---------+
    +-----+----+   +-----+----+   +------+------+
    |Exporters |   | Promtail |   | OTLP (4317) |
    |cadvisor  |   |          |   | OTLP (4318) |
    |node-exp  |   +----------+   +-------------+
    +----------+
```

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Prometheus | `prom/prometheus:v2.54.1` | 9090 | Metrics collection + alerting engine |
| Grafana | `grafana/grafana:11.2.0` | 3000 | Dashboards + visualization + Authentik OIDC |
| Loki | `grafana/loki:3.2.0` | 3100 | Log aggregation |
| Promtail | `grafana/promtail:3.2.0` | — | Log collector (ships to Loki) |
| Tempo | `grafana/tempo:2.6.0` | 3200/4317/4318 | Distributed tracing (OTLP) |
| Alertmanager | `prom/alertmanager:v0.27.0` | 9093 | Alert routing → ntfy push |
| cAdvisor | `gcr.io/cadvisor/cadvisor:v0.50.0` | 8080 | Container metrics |
| Node Exporter | `prom/node-exporter:v1.8.2` | 9100 | Host metrics |
| Uptime Kuma | `louislam/uptime-kuma:1.23.15` | 3001 | Service availability monitoring |

## Prerequisites

- Base stack running (Traefik + proxy network)
- SSO stack running (for Grafana OIDC + dashboard auth)
- Docker logs in `/var/lib/docker/containers`

## Quick Start

```bash
cd stacks/monitoring
cp .env.example .env
nano .env  # Set GRAFANA_ADMIN_PASSWORD, NTFY_TOPIC

docker compose up -d

# Wait for healthy (~30s)
docker compose ps

# Access:
#   Grafana:    https://grafana.DOMAIN     (OIDC via Authentik)
#   Prometheus: https://prometheus.DOMAIN   (ForwardAuth)
#   Alertmgr:   https://alerts.DOMAIN      (ForwardAuth)
#   Status:     https://status.DOMAIN       (Uptime Kuma)
```

## Pre-provisioned Dashboards

| Dashboard | ID | Source |
|-----------|----|--------|
| Node Exporter Full | 1860 | `config/grafana/dashboards/node-exporter-full.json` |
| Docker Container Stats | 179 | `config/grafana/dashboards/docker-container-stats.json` |
| Traefik Official | 17346 | `config/grafana/dashboards/traefik-official.json` |
| Loki Operational | 13639 | `config/grafana/dashboards/loki-operational.json` |
| Uptime Kuma | 18278 | `config/grafana/dashboards/uptime-kuma.json` |

All dashboards auto-load via provisioning. Datasources (Prometheus, Loki, Tempo, Alertmanager) are also auto-configured.

## Alert Rules

| File | Monitors | Key Alerts |
|------|----------|------------|
| `host.yml` | CPU, Memory, Disk, IO | HighCPU, CriticalCPU, DiskSpaceLow/Critical, HighMemory |
| `containers.yml` | Restarts, OOM, Health | ContainerRestarting, OOMKilled, Down, HighCPU/Memory |
| `services.yml` | Traefik, Prometheus, Loki | HighErrorRate, HighLatency, TargetDown |

### Alert Routing

```
Critical → ntfy (urgent push, repeat 1h)
Warning  → ntfy (high priority, repeat 3h)
```

Configure the ntfy topic in `.env`:
```bash
NTFY_TOPIC=your-secret-topic    # Subscribe: https://ntfy.sh/your-secret-topic
```

## Tracing (Tempo)

Tempo receives traces via OTLP:
- **gRPC**: `tempo:4317`
- **HTTP**: `tempo:4318`

Configure your applications to export traces:
```yaml
# Example: OpenTelemetry SDK
OTEL_EXPORTER_OTLP_ENDPOINT: http://tempo:4317
OTEL_EXPORTER_OTLP_PROTOCOL: grpc
```

Grafana links traces from Loki logs via `traceID` derived fields.

## Prometheus Scrape Targets

| Target | Job | Endpoint |
|--------|-----|----------|
| Prometheus | `prometheus` | `localhost:9090` |
| Node Exporter | `node-exporter` | `node-exporter:9100` |
| cAdvisor | `cadvisor` | `cadvisor:8080` |
| Traefik | `traefik` | `traefik:8080` |
| Loki | `loki` | `loki:3100` |
| Authentik | `authentik` | `authentik-server:9300` |
| Uptime Kuma | `uptime-kuma` | `uptime-kuma:3001` |

## Uptime Kuma Setup

After starting the stack:

1. Visit `https://status.DOMAIN`
2. Create admin account
3. Add monitors for each service:
   - `https://grafana.DOMAIN` (HTTP)
   - `https://git.DOMAIN` (HTTP)
   - `https://docs.DOMAIN` (HTTP)
   - `https://nextcloud.DOMAIN` (HTTP)
   - `https://auth.DOMAIN` (HTTP)
   - `https://portainer.DOMAIN` (HTTP)
   - `https://vault.DOMAIN` (HTTP)

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| No metrics | Check Prometheus targets: `https://prometheus.DOMAIN/targets` |
| No logs in Grafana | Verify Promtail can read `/var/lib/docker/containers` |
| No traces | Ensure app exports OTLP to `tempo:4317` |
| Alerts not firing | Check Alertmanager UI: `https://alerts.DOMAIN` |
| ntfy not receiving | Verify topic matches, subscribe at `https://ntfy.sh/TOPIC` |
| Dashboard empty | Check datasource is connected in Grafana → Configuration → Data Sources |
