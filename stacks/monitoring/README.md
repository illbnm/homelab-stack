# Observability Stack

Complete monitoring, logging, alerting, and uptime monitoring stack.

## Services

| Service | Version | Description |
|---------|---------|-------------|
| Prometheus | v2.54.1 | Metrics collection |
| Grafana | 11.2.2 | Visualization & dashboards |
| Loki | 3.2.0 | Log aggregation |
| Promtail | 3.2.0 | Log collection agent |
| Alertmanager | v0.27.0 | Alert routing |
| Node Exporter | v1.8.2 | Host metrics |
| cAdvisor | v0.50.0 | Container metrics |
| Uptime Kuma | 1.23.15 | Service uptime monitoring |

## Quick Start

```bash
# 1. Copy environment template
cp stacks/monitoring/.env.example .env

# 2. Edit .env with your settings
nano .env

# 3. Start the monitoring stack
docker compose -f stacks/monitoring/docker-compose.yml up -d
```

## Service URLs

| Service | URL |
|---------|-----|
| Prometheus | http://localhost:9090 |
| Grafana | https://grafana.${DOMAIN} |
| Loki | http://localhost:3100 |
| Alertmanager | http://localhost:9093 |
| Node Exporter | http://localhost:9100 |
| cAdvisor | http://localhost:8081 |
| Uptime Kuma | https://status.${DOMAIN} |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DOMAIN` | Your domain | `yourdomain.com` |
| `PROMETHEUS_RETENTION` | Prometheus retention | `30d` |
| `LOKI_RETENTION` | Loki retention | `7d` |
| `GRAFANA_ADMIN_USER` | Grafana admin | `admin` |
| `GRAFANA_ADMIN_PASSWORD` | Grafana password | - |

## Dashboards

The following dashboards are auto-provisioned:

| Dashboard | Source |
|-----------|--------|
| Node Exporter Full | ID: 1860 |
| Docker Container Metrics | ID: 179 |
| Loki Logs | ID: 13639 |
| Uptime Kuma | ID: 18278 |

To import manually:
1. Go to Dashboards → Import
2. Enter dashboard ID
3. Select Prometheus as data source

## Alert Rules

Pre-configured alerts in `config/prometheus/rules/`:

### Host Alerts
- High CPU usage (>80% for 5 minutes)
- High memory usage (>90%)
- High disk usage (>85%)

### Container Alerts
- Container down
- Container restart loop (>3 restarts/hour)
- High container CPU usage

## Log Aggregation

Logs are automatically collected from all Docker containers via Promtail.

Access logs via Grafana → Explore → Loki

## Uptime Kuma

Public status page at `https://status.${DOMAIN}`

### Adding Monitors

1. Open Uptime Kuma
2. Add new monitor
3. Configure:
   - Type: HTTP(s)
   - URL: Your service URL
   - Interval: 1 minute
   - Notification: Add ntfy webhook

## Alertmanager Integration

Alerts route through Alertmanager to ntfy:

```yaml
# config/alertmanager/alertmanager.yml
receivers:
  - name: 'ntfy'
    webhook_configs:
      - url: 'http://ntfy:80/homelab-alerts'
```

## CN Mirror Support

For users in China, set in `.env`:

```bash
CN_MODE=true
```

This will use alternative image sources for gcr.io images.

## Health Checks

All services have health checks. Verify:

```bash
docker compose -f stacks/monitoring/docker-compose.yml ps
```

## Prometheus Targets

Access at http://localhost:9090/targets to verify:
- prometheus (self-monitoring)
- node-exporter (host metrics)
- cadvisor (container metrics)
- loki (log metrics)
- alertmanager
- grafana

## Troubleshooting

### Grafana not loading dashboards

Check datasource configuration in Grafana → Configuration → Data Sources.

### No logs in Loki

Verify Promtail is running and can reach Loki:
```bash
docker logs promtail
```

### Alerts not firing

Check Prometheus alert rules:
- http://localhost:9090/rules
- http://localhost:9090/alerts

### High resource usage

cAdvisor and Prometheus can be resource-intensive. Consider:
- Reducing scrape interval
- Limiting metrics collected
- Adjusting retention period

## Security

- Change default Grafana password in `.env`
- Use HTTPS via Traefik
- Consider enabling Authentik OIDC for Grafana
