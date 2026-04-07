# 📊 Monitoring Stack — Prometheus + Grafana + Loki + Alerting

Comprehensive observability stack for monitoring all homelab services, performance metrics, and alerting workflows.

## 🎯 Features

- **Prometheus** - Metrics collection and alerting
- **Grafana** - Visualization dashboards with SSO integration
- **Loki** - Log aggregation system
- **Promtail** - Log collection agent
- **Alertmanager** - Alert routing and notifications
- **cAdvisor** - Container metrics
- **Node Exporter** - Host metrics

## 🚀 Quick Start

### Prerequisites

1. Base infrastructure must be running (Traefik, Portainer)
2. Proxy network created: `docker network create proxy`
3. Environment configured: `cp .env.example .env`

### Deploy Stack

```bash
# Start monitoring stack
cd /home/zhaog/.openclaw/workspace/homelab-stack
./scripts/stack-manager.sh start monitoring

# Check status
docker compose -f stacks/monitoring/docker-compose.yml ps

# View logs
docker compose -f stacks/monitoring/docker-compose.yml logs -f
```

## 📐 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     MONITORING STACK                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐      ┌──────────────┐                     │
│  │   Traefik    │──────│   Grafana    │ ◄── Dashboards      │
│  │  (Ingress)   │      │  (Visualize) │                     │
│  └──────────────┘      └──────┬───────┘                     │
│                               │                              │
│         ┌─────────────────────┼─────────────────────┐       │
│         │                     │                     │        │
│  ┌──────▼────────┐   ┌───────▼───────┐   ┌────────▼──────┐ │
│  │  Prometheus   │   │     Loki      │   │ Alertmanager  │ │
│  │   (Metrics)   │   │    (Logs)     │   │   (Alerts)    │ │
│  └───────┬───────┘   └───────▲───────┘   └───────────────┘ │
│          │                   │                               │
│    ┌─────┴─────┐      ┌──────┴──────┐                      │
│    │ Exporters │      │  Promtail   │                      │
│    │           │      │  (Collector)│                      │
│    └───────────┘      └─────────────┘                      │
│                                                               │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         v                    v                    v
    ┌─────────┐         ┌─────────┐         ┌─────────┐
    │cAdvisor │         │  Node   │         │ Docker  │
    │Container│         │Exporter │         │  Logs   │
    │ Metrics │         │  Host   │         │         │
    └─────────┘         └─────────┘         └─────────┘
```

## 🎛️ Services Overview

### Prometheus (Port 9090)
**URL:** https://prometheus.${DOMAIN}

Metrics collection and alerting engine:
- Scrapes metrics from all services every 15s
- Evaluates alert rules every 15s
- 30-day retention period
- Admin API enabled for advanced operations

**Key Configuration:**
- `config/prometheus/prometheus.yml` - Scrape targets
- `config/prometheus/rules/*.yml` - Alert rules

### Grafana (Port 3000)
**URL:** https://grafana.${DOMAIN}

Visualization and dashboards:
- Pre-configured data sources (Prometheus, Loki)
- SSO integration with Authentik
- Auto-provisioned dashboards
- Custom dashboards in `/var/lib/grafana/dashboards`

**Default Login:**
- Username: `${GRAFANA_ADMIN_USER}` (default: admin)
- Password: `${GRAFANA_ADMIN_PASSWORD}` (set in .env)

### Loki (Port 3100)
**URL:** Internal only (accessed via Grafana)

Log aggregation system:
- Collects logs from all Docker containers
- Stores logs in `/loki/chunks`
- 24-hour index periods
- Integrates with Grafana for log exploration

### Alertmanager (Port 9093)
**URL:** https://alertmanager.${DOMAIN} (if exposed)

Alert routing and notifications:
- Receives alerts from Prometheus
- Routes to notification channels (ntfy, Gotify)
- Deduplication and grouping
- Inhibition rules to reduce noise

### cAdvisor (Port 8080)
**URL:** Internal only

Container metrics exporter:
- CPU, memory, disk I/O per container
- Network usage per container
- Container lifecycle events
- Filesystem usage

### Node Exporter (Port 9100)
**URL:** Internal only

Host metrics exporter:
- CPU, memory, disk usage
- Network statistics
- Filesystem metrics
- System load

## 📊 Dashboards

### Pre-installed Dashboards

1. **Node Exporter Full** - Host metrics
2. **Docker Container Metrics** - Container performance
3. **Traefik Official** - Reverse proxy metrics
4. **Prometheus Stats** - Self-monitoring

### Adding Custom Dashboards

Place JSON dashboard files in:
```
/var/lib/grafana/dashboards/
```

Dashboards are auto-provisioned on restart.

## 🚨 Alerting

### Alert Rules

Located in `config/prometheus/rules/homelab.yml`:

**Critical Alerts:**
- High memory usage (>90% for 5m)
- Low disk space (<10% for 5m)
- Container down (2m)
- Service unreachable

**Warning Alerts:**
- High CPU usage (>85% for 5m)
- High disk I/O
- Certificate expiry soon

### Notification Channels

Configure in `config/alertmanager/alertmanager.yml`:

1. **ntfy** - Primary notification channel
2. **Gotify** - Backup notification channel

**Test Alerts:**
```bash
# Send test alert
curl -X POST http://localhost:9093/api/v2/alerts -d '[{
  "labels": {"alertname": "TestAlert", "severity": "warning"},
  "annotations": {"summary": "Test alert from Alertmanager"}
}]'
```

## 🔧 Configuration

### Environment Variables

See `.env.example` for all options:

```bash
# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=changeme
GRAFANA_OAUTH_CLIENT_ID=
GRAFANA_OAUTH_CLIENT_SECRET=

# Authentik (for SSO)
AUTHENTIK_DOMAIN=auth.yourdomain.com

# Domain
DOMAIN=localhost

# Alerting
ALERTMANAGER_NTFY_TOPIC=homelab-alerts
GOTIFY_TOKEN=
```

### Prometheus Scrapers

Add custom scrape targets in `config/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: my-service
    static_configs:
      - targets: ['my-service:9090']
```

### Loki Log Collection

Promtail automatically collects:
- Docker container logs
- System logs from `/var/log/*.log`

Add custom log paths in `config/loki/promtail-config.yml`:

```yaml
scrape_configs:
  - job_name: custom-logs
    static_configs:
      - targets: [localhost]
        labels:
          job: custom
          __path__: /var/log/custom/*.log
```

## 📈 Monitoring All Services

### Services with Built-in Metrics

These services expose Prometheus metrics:

| Service | Metrics Port | Path |
|---------|--------------|------|
| Traefik | 8080 | `/metrics` |
| Prometheus | 9090 | `/metrics` |
| Loki | 3100 | `/metrics` |
| cAdvisor | 8080 | `/metrics` |
| Node Exporter | 9100 | `/metrics` |

### Services Requiring Exporters

Add exporters for:

**Databases:**
- PostgreSQL: `postgres_exporter`
- Redis: `redis_exporter`
- MariaDB: `mysqld_exporter`

**Media Services:**
- Jellyfin: Built-in metrics (enable in settings)
- qBittorrent: `qbittorrent_exporter`

**Storage:**
- Nextcloud: `nextcloud_exporter`
- MinIO: Built-in metrics at `/minio/v2/metrics/cluster`

## 🔍 Usage Examples

### Query Metrics in Grafana

**CPU Usage:**
```promql
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Memory Usage:**
```promql
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100
```

**Container CPU:**
```promql
rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100
```

**Container Memory:**
```promql
container_memory_usage_bytes{name!=""}
```

### Log Queries in Grafana

**All logs from a container:**
```
{container="traefik"}
```

**Error logs:**
```
{container="traefik"} |= "error"
```

**Logs with pattern:**
```
{container="traefik"} |~ "error|warn"
```

## 🛠️ Maintenance

### Backup Prometheus Data

```bash
# Create snapshot
curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot

# Backup location
ls /prometheus/snapshots/
```

### Backup Grafana Dashboards

```bash
# Export all dashboards
docker exec grafana grafana-cli admin data-migration export /var/lib/grafana/backup
```

### Clean Old Data

```bash
# Prometheus: delete old data
curl -X POST -g 'http://localhost:9090/api/v1/admin/tsdb/delete_series?match[]={job="old-job"}'

# Loki: retention is automatic (30 days)
```

## 🐛 Troubleshooting

### Prometheus Not Scraping

1. Check target status: https://prometheus.${DOMAIN}/targets
2. Verify service is running: `docker ps | grep service-name`
3. Check network connectivity: `docker exec prometheus ping service-name`

### Grafana Can't Connect to Data Source

1. Verify data source URL in Grafana UI
2. Check network: `docker network inspect monitoring`
3. Test connection: `docker exec grafana curl http://prometheus:9090/-/healthy`

### No Logs in Loki

1. Check Promtail status: `docker logs promtail`
2. Verify Docker socket mount: `ls -la /var/run/docker.sock`
3. Check positions file: `docker exec promtail cat /tmp/positions.yaml`

### Alerts Not Firing

1. Check rule syntax: `docker exec prometheus promtool check rules /etc/prometheus/rules/*.yml`
2. View active alerts: https://prometheus.${DOMAIN}/alerts
3. Check Alertmanager logs: `docker logs alertmanager`

## 📚 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [Prometheus Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/dashboards/)

## 🔐 Security Notes

1. **Change default passwords** in `.env`
2. **Restrict access** via Traefik middlewares
3. **Use HTTPS only** for all services
4. **Limit retention** to reduce storage
5. **Regular backups** of Prometheus data and Grafana dashboards

## 🎯 Performance Tuning

### Prometheus

```yaml
# Reduce memory usage
--storage.tsdb.retention.size=10GB

# Faster queries
--query.lookback-delta=5m
```

### Grafana

```yaml
# Increase cache
GF_DATASOURCE_QUERY_CACHE_ENABLED=true
GF_DATASOURCE_QUERY_CACHE_MAX_TTL=300s
```

### Loki

```yaml
# Reduce storage
limits_config:
  max_query_length: 721h
  max_query_parallelism: 32
```

## 📦 Stack Manager Commands

```bash
# Start stack
./scripts/stack-manager.sh start monitoring

# Stop stack
./scripts/stack-manager.sh stop monitoring

# Restart stack
./scripts/stack-manager.sh restart monitoring

# View logs
./scripts/stack-manager.sh logs monitoring

# Update stack
./scripts/stack-manager.sh update monitoring
```

---

**Need help?** Check the [Troubleshooting](#-troubleshooting) section or open an issue.
