# Monitoring Stack

Complete observability stack with metrics, logs, traces, and alerting.

## Services

| Service | Image | Purpose | Port |
|---------|-------|---------|------|
| Prometheus | prom/prometheus:v2.54.1 | Metrics collection & alerting | 9090 |
| Grafana | grafana/grafana:11.2.2 | Visualization & dashboards | 3000 |
| Loki | grafana/loki:3.2.0 | Log aggregation | 3100 |
| Promtail | grafana/promtail:3.2.0 | Log collection agent | 9080 |
| Tempo | grafana/tempo:2.6.0 | Distributed tracing | 3200 |
| Alertmanager | prom/alertmanager:v0.27.0 | Alert routing | 9093 |
| cAdvisor | gcr.io/cadvisor/cadvisor:v0.50.0 | Container metrics | 8080 |
| Node Exporter | prom/node-exporter:v1.8.2 | Host metrics | 9100 |
| Uptime Kuma | louislam/uptime-kuma:1.23.15 | Service availability | 3001 |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GRAFANA (Visualization)                   │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│   │ Prometheus  │  │    Loki     │  │    Tempo    │            │
│   │  (Metrics)  │  │   (Logs)    │  │  (Traces)   │            │
│   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘            │
└──────────┼────────────────┼────────────────┼───────────────────┘
           │                │                │
    ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐
    │  Exporters  │  │  Promtail   │  │  Services   │
    │             │  │             │  │  (OTLP)     │
    └─────────────┘  └─────────────┘  └─────────────┘
         │  │  │
    ┌────┴──┴──┴────┐
    │   cAdvisor    │
    │ Node Exporter │
    │    Traefik    │
    │   Authentik   │
    │   Nextcloud   │
    │     Gitea     │
    └───────────────┘
```

## Quick Start

```bash
# Start monitoring stack
./scripts/stack-manager.sh start monitoring

# Access Grafana
open https://grafana.${DOMAIN}

# Access Uptime Kuma status page
open https://status.${DOMAIN}
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PROMETHEUS_RETENTION` | 30d | Metrics retention period |
| `LOKI_RETENTION` | 168h | Logs retention period (7 days) |
| `TEMPO_RETENTION` | 72h | Traces retention period (3 days) |
| `GRAFANA_ADMIN_USER` | admin | Grafana admin username |
| `GRAFANA_ADMIN_PASSWORD` | - | Grafana admin password |
| `NTFY_TOPIC` | homelab-alerts | ntfy topic for alerts |

### Prometheus Scrape Targets

The following services are automatically scraped:

- **prometheus** - Self-monitoring
- **node-exporter** - Host metrics (CPU, memory, disk, network)
- **cadvisor** - Container metrics
- **traefik** - Reverse proxy metrics
- **loki** - Log storage metrics
- **authentik** - SSO metrics
- **nextcloud** - Storage metrics
- **gitea** - Git metrics
- **ntfy** - Notification metrics

## Dashboards

Pre-configured dashboards are automatically provisioned:

| Dashboard | UID | Description |
|-----------|-----|-------------|
| Node Exporter Full | node-exporter-full | Host metrics (CPU, memory, disk, network) |
| Docker Containers | docker-containers | Container resource usage |
| Traefik Official | traefik-official | Reverse proxy metrics |
| Loki Logs | loki-logs | Log exploration |
| Uptime Kuma | uptime-kuma | Service availability |

## Alerting

### Alert Rules

Alerts are defined in `config/prometheus/rules/`:

- **host.yml** - Host-level alerts (CPU, memory, disk, IO)
- **containers.yml** - Container alerts (restarts, OOM, health)
- **services.yml** - Service alerts (error rates, latency)

### Alert Severity Levels

| Level | Response Time | Notification |
|-------|---------------|--------------|
| Critical | Immediate | ntfy priority 5 |
| Warning | Within 1 hour | ntfy priority 3 |
| Info | Within 24 hours | ntfy priority 1 |

### Alert Routing

All alerts are routed through Alertmanager to ntfy:

```
Alert → Alertmanager → ntfy (homelab-alerts topic) → Mobile/Desktop
```

### Testing Alerts

```bash
# Trigger high CPU alert
stress --cpu 4 --timeout 300

# Or use hey for HTTP load
hey -z 5m -c 100 http://localhost:8080
```

## Uptime Kuma Setup

After starting the stack, run the setup script:

```bash
./scripts/uptime-kuma-setup.sh
```

This will guide you through:
1. Creating an admin account
2. Adding service monitors
3. Configuring notifications
4. Creating a public status page

### Manual Setup

1. Access Uptime Kuma at `https://status.${DOMAIN}`
2. Create admin account
3. Add notification channel (ntfy)
4. Add monitors for services
5. Create status page

## Logs

### Log Sources

Promtail collects logs from:

- All Docker containers (auto-discovery)
- System logs (`/var/log/syslog`)
- Traefik access logs

### Log Queries

In Grafana Explore, use Loki queries:

```logql
# All logs from a container
{container="grafana"}

# Error logs
{job=~".+"} |= "error"

# Logs with trace ID
{job="traefik"} | json | traceId="<trace_id>"
```

## Tracing

Tempo receives traces via:

- **OTLP** (OpenTelemetry): `localhost:4317` (gRPC), `localhost:4318` (HTTP)
- **Jaeger**: `localhost:14250` (gRPC), `localhost:14268` (HTTP)
- **Zipkin**: `localhost:9411`

### Application Integration

```yaml
# Example: Enable tracing in your app
OTEL_EXPORTER_OTLP_ENDPOINT=http://tempo:4317
OTEL_SERVICE_NAME=my-service
```

## Grafana SSO (Authentik)

Grafana is pre-configured for Authentik OIDC:

1. Run `./scripts/setup-authentik.sh` to create OAuth client
2. Access Grafana
3. Click "Sign in with Authentik"

### Role Mapping

- `homelab-admins` group → Grafana Admin role
- `homelab-users` group → Grafana Viewer role

## Troubleshooting

### Prometheus targets not UP

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check service connectivity
docker exec prometheus wget -qO- http://service:port/metrics
```

### Logs not appearing in Loki

```bash
# Check Promtail logs
docker logs promtail

# Check Loki ingestion
curl http://localhost:3100/ready
```

### Alerts not firing

```bash
# Check Prometheus rules
curl http://localhost:9090/api/v1/rules

# Check Alertmanager
curl http://localhost:9093/-/healthy
```

### Grafana dashboards missing

```bash
# Check provisioning
docker exec grafana ls /var/lib/grafana/dashboards

# Check datasources
docker exec grafana cat /etc/grafana/provisioning/datasources/datasources.yml
```

## Maintenance

### Backup Prometheus Data

```bash
# Create snapshot
curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot

# Copy snapshot
docker cp prometheus:/prometheus/snapshots ./prometheus-backup/
```

### Backup Grafana

```bash
# Backup Grafana data
./scripts/backup.sh grafana
```

### Clean Old Data

```bash
# Prometheus retention is automatic
# For manual cleanup:
curl -X POST http://localhost:9090/api/v1/admin/tsdb/delete_series?match[]={job=~".+"}
```

## Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [Tempo Documentation](https://grafana.com/docs/tempo/)
- [Uptime Kuma Wiki](https://github.com/louislam/uptime-kuma/wiki)