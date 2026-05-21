# Observability Stack

Full monitoring, logging, and alerting for HomeLab Stack — metrics, dashboards, log aggregation, and alert management.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Prometheus | v2.54.1 | `prometheus.<DOMAIN>` | Metrics collection & storage |
| Grafana | 11.2.0 | `grafana.<DOMAIN>` | Dashboards & visualization |
| Loki | 3.2.0 | Internal only | Log aggregation |
| Promtail | 3.2.0 | — | Log shipper (container + host logs) |
| Alertmanager | v0.27.0 | Internal only | Alert routing & notification |
| cAdvisor | v0.49.1 | Internal only | Container metrics |
| Node Exporter | v1.8.2 | Internal only | Host system metrics |

## Architecture

```
Host & Containers
    │
    ├──► [Node Exporter] ──► system metrics
    ├──► [cAdvisor] ───────► container metrics
    ├──► [Promtail] ───────► log shipper
    │         │
    ▼         ▼
[Prometheus]    [Loki]
(metrics)       (logs)
    │               │
    └───────┬───────┘
            ▼
        [Grafana] ──── grafana.<DOMAIN> (dashboards)
            │
        [Alertmanager] ── routes alerts to ntfy/email/telegram
```

## Quick Start

```bash
cd stacks/base && docker compose up -d
cd ../monitoring
ln -sf ../../.env .env
docker compose up -d
```

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | Yes | Base domain |
| `GRAFANA_ADMIN_PASSWORD` | Yes | Grafana admin password |
| `GRAFANA_OAUTH_CLIENT_ID` | Yes | Authentik OIDC client ID |
| `GRAFANA_OAUTH_CLIENT_SECRET` | Yes | Authentik OIDC client secret |
| `AUTHENTIK_DOMAIN` | Yes | Authentik domain |

### Grafana Setup

1. Visit `https://grafana.<DOMAIN>`
2. Login with Authentik SSO (or admin/password)
3. Add data sources: Prometheus (`http://prometheus:9090`) and Loki (`http://loki:3100`)
4. Import dashboards: Dashboards → Import → enter Grafana.com ID (e.g., 1860 for Node Exporter)

### Alertmanager Setup

Configure `config/alertmanager/alertmanager.yml` to send alerts to ntfy:
```yaml
receivers:
  - name: 'ntfy'
    webhook_configs:
      - url: 'http://ntfy:80/alerts'
```

## CN Network Adaptation

cAdvisor image is on `gcr.io` — needs CN mirror:

```bash
CN_MODE=true ./scripts/cn-pull.sh
```

All other images on Docker Hub or ghcr.io.

## Health Check

```bash
docker compose ps --format "table {{.Name}}\t{{.Status}}"
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Grafana can't connect to Prometheus | Ensure both on `monitoring` network; use `http://prometheus:9090` |
| No container metrics | Check cAdvisor has Docker socket access |
| No logs in Loki | Verify Promtail config points to correct log paths |
| Alertmanager not sending | Check ntfy stack is running; verify webhook URL |
| cAdvisor image pull fails | gcr.io may be blocked in CN; use mirror |
