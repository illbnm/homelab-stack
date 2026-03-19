# Monitoring Stack — Observability (Issue #10)

This stack provides full observability for homelab services:

- Metrics: Prometheus + cAdvisor + Node Exporter
- Logs: Loki + Promtail
- Traces: Tempo
- Alerting: Alertmanager -> ntfy
- Uptime/SLA: Uptime Kuma
- Visualization: Grafana (pre-provisioned dashboards + datasources)

## Included Services (Pinned)

| Service | Image |
|---|---|
| Prometheus | `prom/prometheus:v2.54.1` |
| Grafana | `grafana/grafana:11.2.2` |
| Loki | `grafana/loki:3.2.0` |
| Promtail | `grafana/promtail:3.2.0` |
| Tempo | `grafana/tempo:2.6.0` |
| Alertmanager | `prom/alertmanager:v0.27.0` |
| cAdvisor | `gcr.io/cadvisor/cadvisor:v0.50.0` |
| Node Exporter | `prom/node-exporter:v1.8.2` |
| Uptime Kuma | `louislam/uptime-kuma:1.23.15` |
| Grafana OnCall (optional profile) | `grafana/oncall:v1.9.22` |

## Required Environment Variables

Copy `stacks/monitoring/.env.example` values into root `.env`.

Important keys:

- `PROMETHEUS_RETENTION=30d`
- `LOKI_RETENTION=7d`
- `TEMPO_RETENTION=3d`
- `NTFY_TOPIC=homelab-alerts`
- `UPTIME_KUMA_USERNAME`, `UPTIME_KUMA_PASSWORD`

## Deploy

```bash
./scripts/stack-manager.sh start monitoring
```

Optional OnCall profile:

```bash
docker compose -f stacks/monitoring/docker-compose.yml --profile oncall up -d
```

## Provisioned Grafana Assets

### Dashboards (auto-loaded from `config/grafana/dashboards/`)

- Node Exporter Full (ID 1860)
- Docker Container & Host Metrics (ID 179)
- Traefik Official (ID 17346)
- Loki Dashboard (ID 13639)
- Uptime Kuma (ID 18278)
- Logs Quick Link (UID: `logs`, path: `/d/logs/logs`)

### Datasources (auto-loaded)

- Prometheus
- Loki
- Tempo (with traces->logs link + service map)

## Prometheus Targets

Configured jobs include:

- `cadvisor`
- `node-exporter`
- `traefik`
- `authentik`
- `nextcloud`
- `gitea`
- `prometheus`

Additional jobs: `loki`, `tempo`, `alertmanager`, `uptime-kuma`.

## Alert Rules

Location: `config/prometheus/alerts/`

- `host.yml`
  - CPU > 80% for 5m
  - Memory > 90%
  - Disk usage > 85%
  - Disk IO anomaly
- `containers.yml`
  - Restarts > 3/hour
  - OOM killed
  - Health check failed
- `services.yml`
  - Traefik 5xx > 1%
  - Service P99 > 2s

## Uptime Kuma Bootstrap

```bash
./scripts/uptime-kuma-setup.sh
```

This script auto-creates monitors via the Uptime Kuma API wrapper.

Public status page is expected at:

- `https://status.${DOMAIN}`

Downtime notifications should be configured to ntfy topic:

- `https://ntfy.${DOMAIN}/${NTFY_TOPIC}`

## Validation

```bash
# Validate compose

docker compose -f stacks/monitoring/docker-compose.yml config

# Validate Prometheus config + rules

docker run --rm -v "$PWD/config/prometheus:/etc/prometheus:ro" prom/prometheus:v2.54.1 \
  promtool check config /etc/prometheus/prometheus.yml

# Validate Alertmanager config

docker run --rm -v "$PWD/config/alertmanager:/etc/alertmanager:ro" prom/alertmanager:v0.27.0 \
  amtool check-config /etc/alertmanager/alertmanager.yml
```
