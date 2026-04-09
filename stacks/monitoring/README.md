# Monitoring Stack - Prometheus + Grafana + Loki + Tempo + Alerting

Comprehensive observability stack for monitoring all homelab services.

**Bounty Task #10** | Difficulty: Hard | Bounty: $280

## Features

| Component | Purpose | Version | Port |
|-----------|---------|---------|------|
| **Prometheus** | Metrics collection & alerting | v2.54.1 | 9090 |
| **Grafana** | Dashboards & visualization | v11.2.0 | 3000 |
| **Loki** | Log aggregation | v3.2.0 | 3100 |
| **Promtail** | Log collection agent | v3.2.0 | 9080 |
| **Tempo** | Distributed tracing | v2.6.0 | 3200 |
| **Alertmanager** | Alert routing & notifications | v0.27.0 | 9093 |
| **cAdvisor** | Container metrics | v0.49.1 | 8080 |
| **Node Exporter** | Host metrics | v1.8.2 | 9100 |
| **Uptime Kuma** | Availability monitoring | v1.23.15 | 3001 |
| **Grafana OnCall** | On-call rotation | v1.9.22 | 8080 |

## Quick Start

```bash
# Prerequisites: Traefik running, proxy network created
cp .env.example .env  # Edit with your values

# Deploy
./scripts/stack-manager.sh start monitoring

# Verify
docker compose -f stacks/monitoring/docker-compose.yml ps
```

## Architecture

```
Traefik (Ingress/TLS)
  |
  +-- Grafana (Dashboards) -- Prometheus (Metrics) -- Alertmanager (Alerts) -- ntfy (Notifications)
  |                          |-- Loki (Logs) -- Promtail (Collector)
  |                          |-- Tempo (Traces)
  |                          +-- cAdvisor + Node Exporter (Exporters)
  +-- Uptime Kuma (Status Page)
  +-- Grafana OnCall (Escalation)
```

## Pre-installed Dashboards

- Node Exporter Full (host metrics)
- Docker Container Metrics
- Traefik Official (reverse proxy)
- Loki Dashboard (log aggregation)
- Uptime Kuma (availability)

Dashboards auto-load from `config/grafana/dashboards/`.

## Alerting

### Alert Rules (`config/prometheus/rules/`)

| File | Scope |
|------|-------|
| `homelab.yml` | Host: CPU, memory, disk, network |
| `containers.yml` | Docker: restart loops, OOM, health checks |
| `services.yml` | Services: Traefik errors, service down |

### Severity Levels

- **Critical**: Immediate (memory >90%, disk <10%, core services down)
- **Warning**: Batched every 4h (CPU >85%, disk <20%, container issues)
- **Info**: Daily (informational)

### Test Alerts

```bash
curl -X POST http://localhost:9093/api/v2/alerts -H 'Content-Type: application/json' -d '[{
  "labels": {"alertname": "TestAlert", "severity": "warning"},
  "annotations": {"summary": "Test alert"}
}]'
```

## Log Queries (LogQL)

```logql
{container="traefik"}               # All logs
{container="traefik"} |= "error"     # Errors only
{container="traefik"} |~ "error|warn"  # Pattern match
```

Log retention: 31 days. Tracing retention: 72 hours.

## Configuration

| File | Purpose |
|------|---------|
| `config/prometheus/prometheus.yml` | Scrape targets |
| `config/prometheus/rules/*.yml` | Alert rules |
| `config/alertmanager/alertmanager.yml` | Alert routing |
| `config/loki/loki-config.yml` | Log storage & retention |
| `config/loki/promtail-config.yml` | Log sources |
| `config/tempo/tempo-config.yml` | Tracing backend |
| `config/grafana/provisioning/` | Auto-config |

## Maintenance

```bash
# Reload config without restart
curl -X POST http://localhost:9090/-/reload

# Validate alert rules
docker exec prometheus promtool check rules /etc/prometheus/rules/*.yml

# Prometheus snapshot
curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot
```

## CN Adaptation

cAdvisor uses `gcr.io` - pull via mirror:
```bash
docker pull gcr.m.daocloud.io/cadvisor/cadvisor:v0.49.1
docker tag gcr.m.daocloud.io/cadvisor/cadvisor:v0.49.1 gcr.io/cadvisor/cadvisor:v0.49.1
```

## Validation

```bash
./scripts/test-monitoring.sh
```
