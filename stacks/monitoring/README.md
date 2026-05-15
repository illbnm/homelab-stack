# Monitoring/Observability Stack

Prometheus + Grafana + Loki + Alertmanager + cAdvisor + Node Exporter.

## Services

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Prometheus | 2.54 | `prometheus.${DOMAIN}` | Metrics collection |
| Grafana | 11.2 | `grafana.${DOMAIN}` | Dashboard & visualization |
| Loki | 3.1 | `loki.${DOMAIN}` | Log aggregation |
| Promtail | 3.1 | — | Log collector |
| Alertmanager | 0.27 | — | Alert routing |
| cAdvisor | 0.49 | — | Container metrics |
| Node Exporter | 1.8 | — | Host metrics |

## Quick Start

```bash
docker compose -f stacks/monitoring/docker-compose.yml up -d
```
