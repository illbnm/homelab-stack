# Observability Stack — Prometheus + Grafana + Loki + Alertmanager

This stack provides full-stack monitoring, logging, and alerting for your homelab. It includes:

- **Prometheus** — metrics collection and alerting rule evaluation
- **Grafana** — visualization dashboards (with SSO via Authentik)
- **Loki** — log aggregation for all containers
- **Promtail** — log collection agent (runs on host)
- **Alertmanager** — alert routing, grouping, and notification
- **cAdvisor** — container resource usage metrics
- **node-exporter** — host system metrics

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Configuration](#configuration)
4. [Access URLs](#access-urls)
5. [Grafana Dashboards](#grafana-dashboards)
6. [Alerting](#alerting)
7. [Health Checks](#health-checks)
8. [Troubleshooting](#troubleshooting)
9. [Bounty Information](#bounty-information)

---

## Prerequisites

- Docker & Docker Compose installed on the host
- Traefik stack running (for reverse proxy)
- Authentik stack running (for SSO to Grafana/Prometheus)
- A valid DNS domain set in `DOMAIN` environment variable

Ensure you have a `.env` file in the homelab root with required variables (see `../../.env.example`).

Required environment variables for this stack:

- `DOMAIN` — your domain (e.g., `homelab.example.com`)
- `AUTHENTIK_DOMAIN` — Authentik URL (e.g., `sso.homelab.example.com`)
- `GRAFANA_ADMIN_USER` — optional, default `admin`
- `GRAFANA_ADMIN_PASSWORD` — optional, default `changeme` (change in production!)
- `GRAFANA_OAUTH_CLIENT_ID` — OAuth2 client ID from Authentik
- `GRAFANA_OAUTH_CLIENT_SECRET` — OAuth2 client secret from Authentik

---

## Quick Start

From the homelab root directory:

```bash
# Create required data directories (if not already present)
mkdir -p data/prometheus data/grafana data/loki

# Launch the monitoring stack
docker compose -f stacks/monitoring/docker-compose.yml up -d
```

Or using the stack-manager script:

```bash
./scripts/stack-manager.sh start monitoring
```

---

## Configuration

### Prometheus

Configuration files:

- `config/prometheus/prometheus.yml` — main scrape config
- `config/prometheus/rules/*.yml` — alerting rules

Default scrape targets:

| Job         | Target             | Description                      |
|-------------|-------------------|----------------------------------|
| prometheus  | localhost:9090    | Prometheus itself                |
| node-exporter | node-exporter:9100 | Host node metrics (CPU, mem, disk, net) |
| cadvisor    | cadvisor:8080     | Docker container metrics         |
| traefik     | traefik:8080      | Traefik dashboard & metrics     |
| loki        | loki:3100         | Loki health                      |

### Grafana

Provisioning:

- `config/grafana/provisioning/datasources/datasources.yml` — auto-adds Prometheus, Loki, Alertmanager
- `config/grafana/provisioning/dashboards/dashboards.yml` — loads dashboards from `config/grafana/dashboards/`

Authentication:

- SSO via Authentik is enabled by default.
- To use local admin/password, set `GF_AUTH_GENERIC_OAUTH_ENABLED=false` in the environment (override in `.env`).

### Loki

Log collection:

- Promtail runs on the host, sending container logs to Loki.
- Logs are stored in `loki_data` volume.
- Loki config: `config/loki/loki-config.yml`

### Alertmanager

Alert routing:

- Config: `config/alertmanager/alertmanager.yml`
- Default receiver is `default` (currently placeholder).
- To enable real notifications, edit the receiver to use Gotify, Slack, or Email (examples provided in the config).

### cAdvisor & node-exporter

These provide low-level resource metrics. They run with necessary privileges and volume mounts to access host `/proc`, `/sys`, `/var/run/docker.sock`, etc.

---

## Access URLs

Once the stack is up, the following URLs should be available through Traefik (HTTPS):

| Service      | URL                                             | Notes                                    |
|--------------|-------------------------------------------------|------------------------------------------|
| Grafana      | `https://grafana.${DOMAIN}`                     | SSO via Authentik, or admin/password    |
| Prometheus   | `https://prometheus.${DOMAIN}`                  | Protected by Authentik middleware       |
| Alertmanager | `https://alertmanager.${DOMAIN}`                | Protected by Authentik middleware       |
| Loki         | `https://loki.${DOMAIN}`                        | Protected by Authentik middleware       |

If Traefik is not yet configured, you can access the services directly on the host:

```bash
grafana:   http://localhost:3000
prometheus: http://localhost:9090
alertmanager: http://localhost:9093
loki: http://localhost:3100
```

---

## Grafana Dashboards

A default dashboard is provided:

- **HomeLab Overview** — displays CPU, memory, disk I/O, network traffic, and container stats.

It is automatically imported via provisioning. Additional dashboards can be added by placing JSON files in `config/grafana/dashboards/` and reloading Grafana.

---

## Alerting

Prometheus evaluates alerting rules from `config/prometheus/rules/*.yml`. When alerts fire, they are sent to Alertmanager, which handles grouping, inhibition, and routing.

To test alerts:

1. Ensure Alertmanager is healthy: `curl http://localhost:9093/-/healthy`
2. Trigger a test alert (e.g., stop a critical service that Prometheus monitors).
3. View alerts in Prometheus UI (Alerts tab) or Alertmanager UI.

Configure actual notification channels (Gotify, Slack, Email) in `config/alertmanager/alertmanager.yml` under `receivers`.

---

## Health Checks

Each service defines a health check. Verify with:

```bash
docker compose -f stacks/monitoring/docker-compose.yml ps
```

All containers should show `State: running` and `Health: healthy`.

Alternatively:

```bash
curl -s http://localhost:9090/-/healthy   # Prometheus
curl -s http://localhost:3000/api/health  # Grafana
curl -s http://localhost:3100/ready       # Loki
curl -s http://localhost:9093/-/healthy  # Alertmanager
```

---

## Troubleshooting

**Grafana shows "Dashboard not found"**

- Ensure the `dashboards` bind mount exists and contains at least one JSON file.
- Check Grafana logs: `docker logs grafana`
- Verify provisioning log: `docker exec grafana cat /var/log/grafana/ provisioning.log`

**Prometheus cannot scrape targets**

- Verify all target services are up and reachable on the Docker network.
- Check Prometheus config: `docker exec prometheus promtool check config /etc/prometheus/prometheus.yml`
- Look for errors in Prometheus UI > Status > Runtime & Build Info.

**No logs in Loki**

- Confirm promtail is running: `docker logs promtail`
- Check Loki query: `curl -G -s "http://localhost:3100/loki/api/v1/query_range" --data-urlencode 'query={container_name="grafana"}'`
- Verify promtail config file is mounted correctly.

**Alerts not firing**

- Check rule syntax: `promtool check rules /etc/prometheus/rules/*.yml` inside the Prometheus container.
- Ensure the Prometheus job `alertmanager` targets the Alertmanager service.
- Use Prometheus "Alerts" page to see state.

---

## Bounty Information

- **Issue:** https://github.com/illbnm/homelab-stack/issues/10
- **Bounty:** $280 (USDT)
- **Acceptance Criteria:**
  1. All services start without errors
  2. Health checks pass
  3. Grafana dashboard (HomeLab Overview) is provisioned automatically
  4. Prometheus scrapes all targets
  5. Loki ingests container logs
  6. Alertmanager config is valid
  7. Documentation provided (this README)
- **Contributor:** Thibault (RavMonSOL)
- **Wallet (Base/ETH):** `0xC33891e6853E21e81491512468160dAB09340BfA`

---

## License

This monitoring stack is part of the homelab-stack project and respects its license.
