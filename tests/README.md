# Observability Stack Test Script

This directory contains test scripts to verify the observability stack setup.

## Test Scripts

### `test-observability.sh`

Tests the complete observability stack:

```bash
./tests/test-observability.sh
```

**Tests**:
- Prometheus targets health
- Grafana accessibility
- Loki log collection
- Alertmanager routing
- cAdvisor metrics
- Node Exporter metrics
- Uptime Kuma status page

## Expected Results

All tests should pass with:
- ✅ Prometheus: All targets UP
- ✅ Grafana: Dashboard accessible
- ✅ Loki: Logs queryable
- ✅ Alertmanager: Notifications configured
- ✅ cAdvisor: Container metrics available
- ✅ Node Exporter: Host metrics available
- ✅ Uptime Kuma: Status page public

## Troubleshooting

### Prometheus Targets DOWN

Check service health:
```bash
docker compose -f stacks/monitoring/docker-compose.yml ps
docker logs prometheus
```

### Grafana Login Fails

Verify OIDC configuration:
```bash
# Check Authentik OAuth credentials
grep GRAFANA_OAUTH .env
# Restart Grafana
docker compose -f stacks/monitoring/docker-compose.yml restart grafana
```

### Loki Logs Not Appearing

Check Promtail logs:
```bash
docker logs promtail
# Verify Promtail can access Docker socket
ls -la /var/run/docker.sock
```

### Alerts Not Firing

Check Prometheus rules:
```bash
# View loaded rules
curl http://localhost:9090/api/v1/rules
# Check alert state
curl http://localhost:9090/api/v1/alerts
```
