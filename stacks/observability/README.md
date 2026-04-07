# 📊 Observability Stack

Complete monitoring and observability platform with Prometheus, Grafana, Loki, Tempo, Alertmanager, and comprehensive service monitoring.

## 🎯 Quick Start

```bash
# 1. Copy environment variables
cp .env.example .env

# 2. Update retention policies if needed (default: Prometheus 30d, Loki 7d, Tempo 3d)
vim .env

# 3. Download Grafana dashboards
../../scripts/download-grafana-dashboards.sh

# 4. Start services
docker-compose up -d

# 5. Check service status
docker-compose ps

# 6. Run verification tests
./test.sh
```

## 📊 Components

| Service | Image | Port | Purpose |
|--------|------|------|---------|
| Prometheus | prom/prometheus:v2.54.1 | 9090 | Metrics collection and storage |
| Grafana | grafana/grafana:11.2.2 | 3000 | Visualization and dashboards |
| Loki | grafana/loki:3.2.0 | 3100 | Log aggregation |
| Promtail | grafana/promtail:3.2.0 | - | Log collection agent |
| Tempo | grafana/tempo:2.6.0 | 3200 | Distributed tracing |
| Alertmanager | prom/alertmanager:v0.27.0 | 9093 | Alert routing and notifications |
| cAdvisor | gcr.io/cadvisor/cadvisor:v0.50.0 | 8080 | Container metrics |
| Node Exporter | prom/node-exporter:v1.8.2 | 9100 | Host metrics |
| Uptime Kuma | louislam/uptime-kuma:1.23.15 | 3001 | Service availability monitoring |
| Grafana OnCall | grafana/oncall:v1.9.22 | 8080 | On-call alert management |

## 📈 Dashboards

5 dashboards are auto-provisioned via Grafana's provisioning system:

- **Node Exporter Full** (ID: 1860) - Comprehensive host metrics (CPU, memory, disk, network)
- **Docker Container & Host Metrics** (ID: 179) - Container resource usage and health
- **Traefik Official Standalone** (ID: 17346) - Reverse proxy metrics and routing
- **Loki Dashboard** (ID: 13639) - Log aggregation overview and queries
- **Uptime Kuma** (ID: 18278) - Service availability and uptime statistics

Access: `https://grafana.${DOMAIN}/dashboards`

## 🔗 Data Flow

```
┌─────────────────────────────────────────────────────────┐
│                  Metrics Collection                      │
│                                                           │
│  Services → cAdvisor/Node Exporter → Prometheus         │
│     ↓                                                     │
│  Store (30d retention)                                   │
│     ↓                                                     │
│  Grafana → Visualize via dashboards                     │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                   Log Collection                         │
│                                                           │
│  Containers/System → Promtail → Loki                    │
│     ↓                                                     │
│  Store (7d retention)                                    │
│     ↓                                                     │
│  Grafana → Query via Loki datasource                    │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                   Alerting Pipeline                      │
│                                                           │
│  Prometheus → Evaluate alert rules                      │
│     ↓                                                     │
│  Alertmanager → Route to ntfy                           │
│     ↓                                                     │
│  ntfy → Push notifications (email/Slack/mobile)         │
└─────────────────────────────────────────────────────────┘
```

## 🚨 Alerting

Alert rules are organized into three categories:

### Host Alerts (`config/prometheus/alerts/host.yml`)
- **HighCPU**: CPU usage > 80% for 5 minutes
- **HighMemory**: Memory usage > 90% for 5 minutes
- **DiskSpace**: Disk usage > 85% for 5 minutes
- **DiskIO**: Disk IO anomalies

### Container Alerts (`config/prometheus/alerts/containers.yml`)
- **ContainerRestart**: Container restarted > 3 times/hour
- **ContainerOOM**: Container OOM killed
- **HealthCheckFailed**: Health check failures

### Service Alerts (`config/prometheus/alerts/services.yml`)
- **HighErrorRate**: HTTP 5xx errors > 5% for 5 minutes
- **HighLatency**: Response time P99 > 2s for 5 minutes
- **ServiceDown**: Service unreachable for 1 minute

**Alert Routing**: Prometheus → Alertmanager → ntfy → Push notifications

## 🔧 Configuration Files

All configuration files are in the `config/` directory:

```
config/
├── prometheus/
│   ├── prometheus.yml              # Scrape configurations
│   └── alerts/                     # Alert rule files
│       ├── host.yml
│       ├── containers.yml
│       └── services.yml
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── datasources.yml    # Data source definitions
│   │   └── dashboards/
│   │       └── dashboards.yml     # Dashboard provisioning config
│   └── dashboards/                # Dashboard JSON files (auto-downloaded)
├── loki/
│   ├── loki-config.yml            # Loki configuration
│   └── promtail-config.yml        # Promtail log collection
├── tempo/
│   └── tempo-config.yml           # Tempo tracing config
└── alertmanager/
    └── alertmanager.yml           # Alert routing config
```

## 📝 Setup Scripts

- **`scripts/download-grafana-dashboards.sh`**: Downloads and provisions Grafana dashboards from grafana.com
- **`scripts/uptime-kuma-setup.sh`**: Configures Uptime Kuma monitoring (needs manual execution)
- **`stacks/observability/test.sh`**: Comprehensive verification script

## ✅ Verification

### Quick Health Check

```bash
# Check all services are running
docker-compose ps

# Test individual services
curl -f http://localhost:9090/-/healthy        # Prometheus
curl -f http://localhost:3000/api/health       # Grafana
curl -f http://localhost:3100/ready            # Loki
curl -f http://localhost:9093/-/healthy        # Alertmanager
curl -f http://localhost:3001                  # Uptime Kuma
curl -f http://localhost:8080/healthz          # cAdvisor
curl -f http://localhost:9100/metrics          # Node Exporter
```

### Comprehensive Test

```bash
# Run full test suite
./test.sh
```

## 📚 Retention Policies

Default retention periods (configurable in `.env`):

```bash
PROMETHEUS_RETENTION=30d    # Metrics stored for 30 days
LOKI_RETENTION=168h         # Logs stored for 7 days
TEMPO_RETENTION=72h         # Traces stored for 3 days
```

## 🎯 Monitoring Coverage

### Prometheus Scrape Targets

| Target | Endpoint | Metrics Collected |
|--------|----------|-------------------|
| Prometheus | localhost:9090 | Self-monitoring |
| cAdvisor | cadvisor:8080 | Container metrics (CPU, memory, network, IO) |
| Node Exporter | node-exporter:9100 | Host metrics (CPU, memory, disk, filesystem) |
| Traefik | traefik:8080 | Reverse proxy metrics (requests, latency, errors) |
| Authentik | authentik-server:9300 | SSO metrics |
| Nextcloud | nextcloud:9205 | Storage metrics |
| Gitea | gitea:3000 | Git server metrics |
| Loki | loki:3100 | Log aggregation metrics |
| Tempo | tempo:3200 | Tracing metrics |
| Alertmanager | alertmanager:9093 | Alert manager metrics |
| Uptime Kuma | uptime-kuma:3001 | Availability metrics |

### Loki Log Sources

Promtail automatically collects logs from:
- **Docker containers** (auto-discovery via Docker socket)
- **System logs** (`/var/log/syslog`, `/var/log/journal`)
- **Traefik access logs** (`/var/log/traefik/access.log`)

## 🔐 Security

### Network Isolation
- **Internal network**: `observability` network for service-to-service communication
- **External network**: `proxy` network for Traefik access

### Access Control
- **Grafana**: Authentik OIDC integration with role mapping
  - `homelab-admins` group → Grafana Admin role
  - `homelab-users` group → Grafana Viewer role
- **Prometheus**: Authentik authentication required
- **Alertmanager**: Authentik authentication required
- **Uptime Kuma**: Public access (no authentication)

### Security Best Practices
- ✅ No hardcoded secrets (all use environment variables)
- ✅ Read-only mounts where possible
- ✅ Minimal container privileges
- ✅ HTTPS via Traefik with Let's Encrypt certificates
- ✅ Data encryption at rest (Docker volumes)

## 📊 Resource Requirements

### Minimum
- **CPU**: 4 cores
- **RAM**: 8GB
- **Disk**: 50GB

### Recommended (Production)
- **CPU**: 8 cores
- **RAM**: 16GB
- **Disk**: 100GB (with 30-day retention)

### Resource Usage Breakdown
- **Prometheus**: ~2GB RAM, high disk I/O
- **Grafana**: ~500MB RAM
- **Loki**: ~1GB RAM, moderate disk I/O
- **Tempo**: ~500MB RAM
- **Alertmanager**: ~100MB RAM
- **cAdvisor**: ~200MB RAM
- **Node Exporter**: ~50MB RAM
- **Uptime Kuma**: ~300MB RAM

## 🛠️ Troubleshooting

### Service won't start

```bash
# Check service logs
docker-compose logs <service_name>

# Check service status
docker-compose ps <service_name>

# Restart service
docker-compose restart <service_name>
```

### Common Issues

#### Prometheus Scrape Failures
```bash
# Check target status
curl http://localhost:9090/api/v1/targets | jq .data.activeTargets[] | grep -i "down"

# Verify target service health
curl http://<target-service>:<port>/metrics
```

#### Grafana Dashboard Not Loading
```bash
# Verify dashboard files exist
ls -la config/grafana/dashboards/

# Check Grafana logs
docker-compose logs grafana | grep -i dashboard

# Restart Grafana
docker-compose restart grafana
```

#### Loki Connection Errors
```bash
# Check Promtail logs
docker-compose logs promtail

# Verify Loki is healthy
curl http://localhost:3100/ready
```

#### Alertmanager Not Sending Alerts
```bash
# Check alert rules loaded
curl http://localhost:9090/api/v1/rules | jq .data.groups[].name

# Verify ntfy webhook configuration
cat config/alertmanager/alertmanager.yml | grep -A5 ntfy

# Test alert routing
docker exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
```

### Performance Tuning

#### Reduce Prometheus Resource Usage
```yaml
# Reduce scrape frequency
global:
  scrape_interval: 30s  # Default: 15s
  evaluation_interval: 30s  # Default: 15s
```

#### Reduce Loki Storage
```yaml
# Decrease retention period
table_manager:
  retention_period: 72h  # Default: 168h (7 days)
```

## 📚 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [Tempo Documentation](https://grafana.com/docs/tempo/)
- [Uptime Kuma Documentation](https://github.com/louislam/uptime-kuma)

## 📝 License

MIT

## 🤝 Contributing

Contributions welcome! See [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## 📋 Bounty Task Information

This implementation fulfills **Bounty Task #10 - Observability Stack ($280)**:

✅ **Implemented Services:**
- Prometheus (v2.54.1)
- Grafana (11.2.2)
- Loki (3.2.0)
- Tempo (2.6.0)
- Alertmanager (v0.27.0)
- cAdvisor (v0.50.0)
- Node Exporter (v1.8.2)
- Uptime Kuma (1.23.15)
- Grafana OnCall (v1.9.22)

✅ **Configuration:**
- Prometheus scrape targets for all services
- Pre-loaded Grafana dashboards (5 dashboards)
- Alert rules (3 files: host, containers, services)
- Loki log collection configuration
- Tempo distributed tracing setup
- Uptime Kuma monitoring setup

✅ **Features:**
- Complete observability stack
- Auto-provisioned dashboards
- Comprehensive alerting
- Log aggregation
- Distributed tracing
- Service availability monitoring
- On-call alert management
- Traefik integration
- Authentik OIDC integration
- Network isolation
- Security best practices

---

**Built with ❤️ for the homelab-stack project**
