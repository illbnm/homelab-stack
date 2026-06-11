# Observability Stack — Prometheus + Grafana + Loki + Promtail

Complete monitoring and logging solution for the homelab.

## Deployment
1. Customize Grafana credentials in docker-compose.yml.
2. Start the stack: `docker compose up -d`
3. Access Grafana at `https://grafana.yourdomain.com` (or via Traefik labels).
4. Add Prometheus data source in Grafana: http://prometheus:9090
5. Add Loki data source in Grafana: http://loki:3100
