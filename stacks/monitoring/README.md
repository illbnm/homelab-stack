# Observability Stack

Full-stack monitoring: metrics, logs, traces, alerting, and uptime monitoring.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Prometheus | 2.54 | `prometheus.<DOMAIN>` | Metrics collection + storage |
| Grafana | 11.2 | `grafana.<DOMAIN>` | Metrics visualization & dashboards |
| Loki | 3.2 | internal | Log aggregation |
| Promtail | 3.2 | — | Log collection agent |
| Alertmanager | 0.27 | internal | Alert routing & deduplication |
| cAdvisor | 0.49 | — | Container metrics |
| Node Exporter | 1.8 | — | Host hardware metrics |
| Tempo | 2.6 | internal | Distributed tracing (OTLP) |
| Uptime Kuma | 1.23 | `uptime.<DOMAIN>` | Uptime monitoring & status pages |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Observability Stack                    │
│                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │ Prometheus  │  │    Loki    │  │     Tempo      │  │
│  │  (metrics)  │  │   (logs)   │  │   (traces)     │  │
│  └──────┬──────┘  └──────┬──────┘  └────────┬────────┘  │
│         │                │                   │         │
│         └────────────────┼───────────────────┘         │
│                          │                             │
│                    ┌─────▼─────┐                      │
│                    │  Grafana  │                      │
│                    │(dashboards│                      │
│                    │ + alerts) │                      │
│                    └───────────┘                       │
│                                                          │
│  ┌──────────┐  ┌────────────┐  ┌───────────────────┐   │
│  │cAdvisor  │  │Node-Exp.   │  │  Uptime Kuma      │   │
│  │(containers)│ │(host hw)  │  │ (uptime monitoring)│  │
│  └──────────┘  └────────────┘  └───────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

- Base Infrastructure (Traefik) deployed first
- SSO Stack (Authentik) deployed for Grafana OAuth

## Quick Start

```bash
cd stacks/monitoring
cp .env.example .env
# Edit .env with Grafana credentials

docker compose up -d
```

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain |
| `TZ` | ✅ | Timezone |
| `AUTHENTIK_DOMAIN` | ✅ | SSO domain for Grafana OAuth |
| `GRAFANA_ADMIN_USER` | — | Admin username (default: admin) |
| `GRAFANA_ADMIN_PASSWORD` | — | Admin password (default: changeme) |
| `GRAFANA_OAUTH_CLIENT_ID` | ✅ | Authentik OAuth client ID |
| `GRAFANA_OAUTH_CLIENT_SECRET` | ✅ | Authentik OAuth client secret |

### Grafana OAuth Setup

1. In Authentik, create an application for Grafana with:
   - Redirect URI: `https://grafana.${DOMAIN}/finish_login/`
2. Set `GRAFANA_OAUTH_CLIENT_ID` and `GRAFANA_OAUTH_CLIENT_SECRET` in `.env`

## Service URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Prometheus | `https://prometheus.${DOMAIN}` | No auth |
| Grafana | `https://grafana.${DOMAIN}` | Authentik SSO or admin/changeme |
| Uptime Kuma | `https://uptime.${DOMAIN}` | Set password on first login |

## Adding Tracing to Services

To send traces to Tempo, instrument your services with OpenTelemetry:

```yaml
# Example: adding OTLP exporter to a service
environment:
  - OTEL_EXPORTER_OTLP_ENDPOINT=http://tempo:4317
```

Grafana can then query Tempo for distributed traces alongside Prometheus metrics and Loki logs.

## Alertmanager Integration

Alertmanager receives alerts from Prometheus and routes them to notification channels (email, Slack, webhook, etc.).

Configure in `config/alertmanager/alertmanager.yml`:

```yaml
route:
  receiver: 'default-receiver'
receivers:
  - name: 'default-receiver'
    # Add email, slack, webhook config here
```

## Uptime Kuma

Add monitors for your services:
- **HTTP monitoring**: `https://portainer.${DOMAIN}`, `https://vault.${DOMAIN}`, etc.
- **TCP monitoring**: Custom ports
- **Ping monitoring**: Host availability
- **Keyword monitoring**: Check for specific text in responses

Set up notifications (email, Telegram, Slack) to be alerted when services go down.

## Grafana Dashboards

Import useful dashboards:
- **Docker monitoring**: Dashboard ID `13623`
- **Node Exporter Full**: Dashboard ID `1860`
- **Grafana Loki**: Dashboard ID `14018`

## Troubleshooting

### Prometheus not scraping targets
- Check `config/prometheus/prometheus.yml` for correct target addresses
- Verify all target services are on the `monitoring` network
- Check `docker logs prometheus` for scrape errors

### Grafana shows "Unauthorized"
- Verify `GRAFANA_OAUTH_CLIENT_ID` and `GRAFANA_OAUTH_CLIENT_SECRET` are correct
- Ensure Authentik application has correct redirect URI
- Check browser console for CORS errors

### Tempo traces not appearing
- Ensure services are instrumented with OpenTelemetry
- Verify `OTEL_EXPORTER_OTLP_ENDPOINT=http://tempo:4317` is set
- Check Tempo logs: `docker logs tempo`
