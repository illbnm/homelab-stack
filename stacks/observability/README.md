# Observability Stack

Complete observability stack with metrics, logs, traces, and alerting.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Prometheus | `prom/prometheus:v2.54.1` | 9090 | Metrics collection |
| Grafana | `grafana/grafana:11.2.2` | 3000 | Visualization |
| Loki | `grafana/loki:3.2.0` | 3100 | Log aggregation |
| Promtail | `grafana/promtail:3.2.0` | 9080 | Log collection |
| Tempo | `grafana/tempo:2.6.0` | 3200 | Distributed tracing |
| Alertmanager | `prom/alertmanager:v0.27.0` | 9093 | Alert routing |
| cAdvisor | `gcr.io/cadvisor/cadvisor:v0.50.0` | 8080 | Container metrics |
| Node Exporter | `prom/node-exporter:v1.8.2` | 9100 | Host metrics |
| Uptime Kuma | `louislam/uptime-kuma:1.23.15` | 3001 | Service availability |

## Quick Start

### 1. Configure Environment

```bash
cp .env.example .env
nano .env
```

### 2. Start Services

```bash
docker compose up -d
```

### 3. Access Services

| Service | URL |
|---------|-----|
| Grafana | https://grafana.yourdomain.com |
| Prometheus | https://prometheus.yourdomain.com |
| Alertmanager | https://alertmanager.yourdomain.com |
| Uptime Kuma | https://status.yourdomain.com |

## Configuration

### Prometheus Targets

| Job | Target | Purpose |
|-----|--------|---------|
| prometheus | localhost:9090 | Self-monitoring |
| node-exporter | node-exporter:9100 | Host metrics |
| cadvisor | cadvisor:8080 | Container metrics |
| traefik | traefik:8080 | Reverse proxy metrics |
| authentik | authentik-server:9300 | SSO metrics |
| nextcloud | nextcloud:80 | Storage metrics |
| gitea | gitea:3000 | Git metrics |

### Grafana Dashboards

Pre-configured dashboards:
- Node Exporter Full (ID: 1860)
- Docker Container Metrics (ID: 179)
- Traefik Official (ID: 17346)
- Loki Logs (ID: 13639)
- Uptime Kuma (ID: 18278)

### Alert Rules

#### Host Alerts
- CPU > 80% for 5 minutes
- Memory > 90%
- Disk > 85%
- Disk I/O anomalies

#### Container Alerts
- Restart count > 3/hour
- OOM killed
- Health check failed

#### Service Alerts
- Traefik 5xx rate > 1%
- P99 latency > 2s

### Alertmanager Integration

Alerts are routed to ntfy:
- Critical → `ntfy/alerts?priority=5`
- Warning → `ntfy/alerts?priority=3`

### Uptime Kuma Setup

```bash
# Auto-configure monitors
./scripts/uptime-kuma-setup.sh
```

## Health Checks

```bash
# Prometheus
curl -sf http://localhost:9090/-/healthy

# Grafana
curl -sf http://localhost:3000/api/health

# Loki
curl -sf http://localhost:3100/ready

# Tempo
curl -sf http://localhost:3200/ready

# Alertmanager
curl -sf http://localhost:9093/-/healthy

# cAdvisor
curl -sf http://localhost:8080/healthz

# Node Exporter
curl -sf http://localhost:9100/metrics

# Uptime Kuma
curl -sf http://localhost:3001/health
```

## Resource Requirements

| Service | Min Memory | Recommended |
|---------|------------|-------------|
| Prometheus | 512 MB | 1-2 GB |
| Grafana | 128 MB | 256 MB |
| Loki | 256 MB | 512 MB - 1 GB |
| Promtail | 64 MB | 128 MB |
| Tempo | 128 MB | 256 MB |
| Alertmanager | 64 MB | 128 MB |
| cAdvisor | 128 MB | 256 MB |
| Node Exporter | 32 MB | 64 MB |
| Uptime Kuma | 128 MB | 256 MB |
| **Total** | **1.4 GB** | **2.8 - 4.5 GB** |

## Data Retention

- Prometheus: 30 days
- Loki: 7 days
- Tempo: 3 days

## Troubleshooting

### Prometheus Targets Down

```bash
# Check target status
curl http://localhost:9090/api/v1/targets

# Check logs
docker logs prometheus
```

### Grafana Dashboard Missing

```bash
# Check provisioning
ls config/grafana/provisioning/dashboards/

# Restart Grafana
docker restart grafana
```

### Alerts Not Sending

```bash
# Check Alertmanager status
curl http://localhost:9093/-/healthy

# Check ntfy connection
curl http://ntfy:80/health
```

## License

MIT
