# Monitoring Stack - Complete Observability

This stack provides a comprehensive observability solution covering metrics, logs, traces, and alerting for your homelab.

## 🎯 Components

### Core Monitoring
- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards
- **Alertmanager** - Alert routing and management

### Logging
- **Loki** - Log aggregation
- **Promtail** - Log collection agent

### Tracing
- **Tempo** - Distributed tracing backend

### Container & Host Monitoring
- **cAdvisor** - Container resource metrics
- **Node Exporter** - Host system metrics

### Uptime Monitoring
- **Uptime Kuma** - Service availability monitoring

### On-Call Management
- **Grafana OnCall** - Alert escalation and on-call management

## 📊 Pre-configured Dashboards

The following Grafana dashboards are automatically provisioned:

1. **Node Exporter Full** (ID: 1860) - Complete host metrics
2. **Docker Container & Host Metrics** (ID: 179) - Container resource usage
3. **Traefik Official** (ID: 17346) - Reverse proxy metrics
4. **Loki Dashboard** (ID: 13639) - Log aggregation insights
5. **Uptime Kuma** (ID: 18278) - Service availability overview

## 🚨 Alert Rules

### Host Alerts (`config/prometheus/rules/host.yml`)
- High CPU usage (>80% for 5 minutes)
- High memory usage (>90% for 5 minutes)
- Low disk space (>85% usage)
- High disk IO

### Container Alerts (`config/prometheus/rules/containers.yml`)
- Frequent restarts (>3 times/hour)
- OOM killed events
- Health check failures
- High resource usage

### Service Alerts (`config/prometheus/rules/services.yml`)
- Traefik 5xx error rate (>1%)
- Slow response times (P99 > 2s)
- Service down detection

## 🔔 Notification Routing

All alerts are routed through Alertmanager to ntfy:

- **Critical alerts** → Priority: urgent, Tag: critical
- **Warning alerts** → Priority: high, Tag: warning

## 📡 Prometheus Scrape Targets

The following services are monitored:

- `prometheus` - Self-monitoring
- `node-exporter` - Host metrics
- `cadvisor` - Container metrics
- `traefik` - Reverse proxy metrics
- `loki` - Log aggregation metrics
- `authentik` - SSO metrics
- `nextcloud` - Storage metrics
- `gitea` - Git metrics

## 🗄️ Data Retention

Default retention policies:

- **Prometheus**: 30 days
- **Loki**: 7 days
- **Tempo**: 3 days

Configure in `.env`:

```bash
PROMETHEUS_RETENTION=30d
LOKI_RETENTION=168h  # 7 days
TEMPO_RETENTION=72h  # 3 days
```

## 🚀 Quick Start

### 1. Configure Environment

```bash
cp .env.example .env
# Edit .env with your settings
```

Required variables:

```bash
DOMAIN=yourdomain.com
AUTHENTIK_DOMAIN=auth.yourdomain.com
GRAFANA_OAUTH_CLIENT_ID=<from-authentik>
GRAFANA_OAUTH_CLIENT_SECRET=<from-authentik>
ONCALL_SECRET_KEY=<random-string>
NTFY_TOKEN=<optional-bearer-token>
```

### 2. Deploy the Stack

```bash
docker-compose up -d
```

### 3. Configure Grafana OIDC

In Authentik, create an OAuth provider for Grafana:

- Name: `Grafana`
- Authorization flow: `explicit-consent`
- Redirect URIs: `https://grafana.${DOMAIN}/login/generic_oauth`

Groups:

- `homelab-admins` → Grafana Admin role
- `homelab-users` → Grafana Viewer role

### 4. Set Up Uptime Kuma

Run the setup script:

```bash
cd scripts
./uptime-kuma-setup.sh
```

Follow the instructions to:

1. Create admin account at `https://status.${DOMAIN}`
2. Add monitors for all services
3. Configure ntfy notifications

### 5. Verify Setup

Check that all services are running:

```bash
docker-compose ps
```

Verify Prometheus targets:

1. Open `https://prometheus.${DOMAIN}`
2. Go to Status → Targets
3. All targets should show **UP**

## 🔧 Configuration Files

```
config/
├── prometheus/
│   ├── prometheus.yml          # Scrape configuration
│   └── rules/
│       ├── host.yml             # Host alert rules
│       ├── containers.yml       # Container alert rules
│       └── services.yml         # Service alert rules
├── alertmanager/
│   └── alertmanager.yml        # Alert routing config
├── loki/
│   ├── loki-config.yml         # Loki configuration
│   └── promtail-config.yml     # Log collection config
└── grafana/
    ├── provisioning/
    │   ├── datasources/        # Datasource configs
    │   └── dashboards/         # Dashboard provisioning
    └── dashboards/              # Dashboard JSON files
```

## 📖 Usage

### Accessing Dashboards

- **Grafana**: `https://grafana.${DOMAIN}`
- **Prometheus**: `https://prometheus.${DOMAIN}`
- **Uptime Kuma**: `https://status.${DOMAIN}`
- **Grafana OnCall**: `https://oncall.${DOMAIN}`

### Querying Logs

In Grafana:

1. Go to Explore
2. Select Loki datasource
3. Query examples:
   ```
   {job="docker-containers"} |= "error"
   {container="traefik"} | json | level="error"
   ```

### Tracing

In Grafana:

1. Go to Explore
2. Select Tempo datasource
3. Search by trace ID or service name

### Alert Testing

Test alerts by triggering conditions:

```bash
# High CPU (run for 6 minutes)
stress --cpu 4 --timeout 360

# Check Alertmanager
curl http://localhost:9093/api/v2/alerts
```

## 🔍 Verification Checklist

- [ ] Grafana accessible with Authentik login
- [ ] All dashboards loaded automatically
- [ ] Prometheus targets all showing UP
- [ ] Loki can query container logs
- [ ] Alertmanager receiving alerts
- [ ] ntfy receiving notifications
- [ ] Uptime Kuma monitoring all services
- [ ] Status page publicly accessible at `status.${DOMAIN}`

## 🐛 Troubleshooting

### Prometheus targets not UP

1. Check service is running: `docker-compose ps`
2. Verify network connectivity
3. Check service exposes metrics endpoint

### Grafana dashboards not loading

1. Check provisioning logs: `docker logs grafana`
2. Verify volume mounts
3. Check dashboard JSON format

### Alerts not sending to ntfy

1. Check Alertmanager logs: `docker logs alertmanager`
2. Verify ntfy is accessible
3. Test Alertmanager config: `amtool check-config`

### Loki not receiving logs

1. Check Promtail logs: `docker logs promtail`
2. Verify Docker socket access
3. Check Loki is healthy: `curl http://localhost:3100/ready`

## 📚 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [Tempo Documentation](https://grafana.com/docs/tempo/)
- [Uptime Kuma Wiki](https://github.com/louislam/uptime-kuma/wiki)

## 🔄 Updates

To update the monitoring stack:

```bash
docker-compose pull
docker-compose up -d
```

Dashboard updates:

```bash
cd scripts
./download-dashboards.sh
docker-compose restart grafana
```
