# Monitoring Stack

Complete observability stack for the homelab with Metrics, Logs, Traces, and Alerts.

## Services

| Service | Port | Purpose |
|---------|------|---------|
| Prometheus | 9090 | Metrics collection and alerting |
| Grafana | 3000 | Visualization and dashboards |
| Loki | 3100 | Log aggregation |
| Promtail | 9080 | Log collection agent |
| Tempo | 3200 | Distributed tracing |
| Alertmanager | 9093 | Alert routing and notifications |
| cAdvisor | 8080 | Container metrics |
| Node Exporter | 9100 | Host metrics |
| Uptime Kuma | 3001 | Service availability monitoring |
| Grafana OnCall | 8080 | Oncall alert management |

## Quick Start

```bash
# Start the monitoring stack
docker-compose up -d

# Access Grafana
open https://grafana.${DOMAIN}

# Default credentials (change in production!)
Username: admin
Password: changeme
```

## Pre-configured Dashboards

The following dashboards are automatically provisioned:

1. **Node Exporter Full** - Comprehensive host metrics
2. **Docker Container & Host Metrics** - Container resource usage
3. **Traefik Official** - Reverse proxy metrics
4. **Loki Dashboard** - Log aggregation overview
5. **Uptime Kuma** - Service availability status

## Metrics Collection

### Prometheus Targets

Prometheus is configured to scrape metrics from:

- **prometheus** - Self-monitoring
- **node-exporter** - Host metrics (CPU, memory, disk, network)
- **cadvisor** - Container metrics
- **traefik** - Reverse proxy metrics
- **loki** - Log aggregation metrics
- **tempo** - Distributed tracing metrics
- **authentik** - SSO metrics
- **nextcloud** - Storage metrics
- **gitea** - Git service metrics
- **uptime-kuma** - Availability monitoring metrics
- **grafana** - Dashboard metrics
- **alertmanager** - Alert metrics

## Log Collection

### Promtail Configuration

Promtail collects logs from:

- **Docker containers** - All container logs via auto-discovery
- **System logs** - `/var/log/syslog`
- **Traefik access logs** - `/var/log/traefik/access.log`
- **Authentik logs** - Authentication service logs

### Log Queries in Grafana

Access logs in Grafana Explore:

```
# View all container logs
{container=~".+"}

# Filter by service
{service="traefik"}

# Filter by log level
{service="authentik"} |= "error"

# Syslog queries
{job="syslog"} |= "failed"
```

## Distributed Tracing

Tempo provides distributed tracing support. Configure your applications to send traces to:

- **HTTP**: `http://tempo:4318/v1/traces`
- **gRPC**: `tempo:4317`

View traces in Grafana Explore → Tempo datasource.

## Alerting

### Alert Rules

Three types of alert rules are configured:

1. **homelab.yml** - Host-level alerts
   - CPU > 85%
   - Memory > 90%
   - Disk space < 10%
   - Disk I/O anomalies
   - Network errors

2. **containers.yml** - Container-level alerts
   - Container restart loops
   - OOM kills
   - Health check failures
   - High resource usage

3. **services.yml** - Service-level alerts
   - Traefik 5xx error rate > 1%
   - Service response time P99 > 2s
   - Service down alerts

### Alert Routing

All alerts are routed through Alertmanager to ntfy for notifications.

### Test Alerts

```bash
# Trigger high CPU alert
stress --cpu 4 --timeout 300

# Trigger container restart alert
docker restart some-container (multiple times)

# View alerts in Alertmanager
open https://alertmanager.${DOMAIN}
```

## Uptime Kuma

Service availability monitoring with public status page.

### Setup

```bash
# Run the setup script to create monitors for all services
./scripts/uptime-kuma-setup.sh

# Access status page
open https://status.${DOMAIN}
```

### Manual Configuration

1. Access Uptime Kuma: https://status.${DOMAIN}
2. Create admin account
3. Add notification channels (ntfy, email, etc.)
4. Create status page for public access

## Grafana Authentication

Grafana is configured for Authentik OIDC:

- `homelab-admins` group → Admin role
- `homelab-users` group → Viewer role

### Setup OAuth in Authentik

1. Create OAuth provider in Authentik
2. Set redirect URI: `https://grafana.${DOMAIN}/login/generic_oauth`
3. Copy client ID and secret to `.env`:
   ```
   GRAFANA_OAUTH_CLIENT_ID=<client-id>
   GRAFANA_OAUTH_CLIENT_SECRET=<client-secret>
   ```

## Data Retention

Default retention policies (configure in `.env`):

- **Prometheus**: 30 days
- **Loki**: 7 days
- **Tempo**: 3 days

## Grafana OnCall

Oncall rotation and alert management:

- Access: https://oncall.${DOMAIN}
- Integrates with Grafana Alerting
- Manages notification routing and escalations

## Troubleshooting

### Check Service Status

```bash
# Check all monitoring services
docker-compose ps

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check Loki logs
docker logs loki

# Check Promtail logs
docker logs promtail
```

### Common Issues

1. **Grafana dashboards not loading**
   - Check datasource provisioning
   - Verify Prometheus and Loki are running

2. **No metrics appearing**
   - Check Prometheus targets page
   - Verify service endpoints are accessible

3. **Logs not appearing in Loki**
   - Check Promtail logs
   - Verify Docker socket mount

4. **Alerts not firing**
   - Check Prometheus rules page
   - Verify Alertmanager configuration

## Security Notes

- Change default Grafana password
- Configure proper authentication
- Restrict access to monitoring endpoints
- Use HTTPS for all services
- Review and update alert thresholds for your environment

## Maintenance

### Backup Grafana Dashboards

```bash
# Export dashboards
docker exec grafana grafana-cli admin data-migration export /var/lib/grafana/backup
```

### Clean Old Data

```bash
# Clean Prometheus data older than retention
# (Automatic with retention settings)

# Clean Loki chunks
# (Automatic with compactor enabled)
```
