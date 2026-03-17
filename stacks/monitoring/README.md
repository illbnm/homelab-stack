# Observability Stack

Full metrics / logs / alerting / uptime monitoring for your homelab.

## Services

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Prometheus | v2.54.1 | prometheus.yourdomain.com | Metrics collection |
| Grafana | 11.2.0 | grafana.yourdomain.com | Visualization |
| Loki | 3.1.0 | internal | Log aggregation |
| Promtail | 3.1.0 | internal | Log shipper |
| Alertmanager | v0.27.0 | internal | Alert routing |
| Node Exporter | v1.8.2 | internal | Host metrics |
| cAdvisor | v0.49.1 | internal | Container metrics |
| Uptime Kuma | latest | uptime.yourdomain.com | SLA monitoring |

## Setup

```bash
cp .env.example .env
nano .env   # Set GF_ADMIN_PASSWORD, DOMAIN, email settings

docker compose up -d
```

## Access

- **Grafana**: https://grafana.yourdomain.com — login with GF_ADMIN_USER/GF_ADMIN_PASSWORD
  - Prometheus and Loki datasources are **auto-provisioned** (no manual setup needed)
- **Uptime Kuma**: https://uptime.yourdomain.com — first visit creates admin account

## Grafana Datasources

Pre-configured automatically via provisioning:
- **Prometheus** (default) — metrics queries
- **Loki** — log queries (`{container_name="traefik"} |= "error"`)

## Alerting

Edit `config/alertmanager.yml` to set your notification channel.
Default rules in `config/alert-rules.yml`:
- Container down (1m)
- High CPU > 85% (5m)
- High memory > 90% (5m)
- Disk > 85% full (5m)

## Requires

- Base stack running (proxy network)
