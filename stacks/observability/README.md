# 📊 Observability Stack

Complete monitoring and observability platform with Prometheus, Grafana, Loki, Tempo, Alertmanager, and comprehensive service monitoring.

## 🎯 Quick Start

```bash
# 1. Ensure environment variables are configured
cp .env.example . .env
# 2. Update retention policies if needed
#    PROMetheus: 30 days
#    Loki: 7 days
#    Tempo: 3 days (72h)
# 3. Start services
docker-compose up -d

#  4. Wait for services to be healthy
docker-compose ps

#  5. Access Grafana
#    URL: https://grafana.${DOMAIN}
#    Default login: admin / ${GRAFANA_ADMIN_PASSWORD}
#    Note: First-time setup requires creating admin password

#  6. Access dashboards
#    URL: https://grafana.${DOMAIN}/dashboards
#    Default: Node Exporter Full, Other dashboards will be auto-provisioned

#  7. Access Prometheus
#    URL: https://prometheus.${DOMAIN}
#    Restricted access (requires Authentik authentication)

#  8. Access Alertmanager
#    URL: https://alertmanager.${DOMAIN}
#    Restricted access (requires Authentik authentication)

#  9. Access Uptime Kuma
#    URL: https://status.${DOMAIN}
#    Public access (no authentication required)

#  10. View status page
#    URL: https://status.${DOMAIN}
#    First-time setup creates admin account
#    Status page is public (no authentication)

#  11. Configure Uptime Kuma monitors
#    Run: ../../scripts/uptime-kuma-setup.sh
#    This will create monitors for all services and configure ntfy notifications

#  12. Verify setup
#    Check Prometheus targets: https://prometheus.${DOMAIN}/targets
#    Check Grafana dashboards: https://grafana.${DOMAIN}/dashboards
#    Query logs in Loki: https://grafana.${DOMAIN}/explore
#    Test alerting: Manually trigger CPU spike with `stress --cpu 4`
#    Verify ntfy receives alert (5 minutes)

#  13. Configure Grafana OnCall (optional)
#    Access at: https://grafana.${DOMAIN}/plugins
#    Configure Slack integration if desired

## 📊 Components

| Service | Image | Port | Purpose |
|--------|------|------|---------|
| Prometheus | prom/prometheus:v2.54.1 | 9090 | Metrics collection and storage |
| Grafana | grafana/grafana:11.2.2 | 3000 | Visualization and dashboards |
| Loki | grafana/loki:3.2.0 | 3100 | Log aggregation |
| Promtail | grafana/promtail:3.2.0 | Log collection agent |
| Tempo | grafana/tempo:2.6.0 | 3200 | Distributed tracing |
| Alertmanager | prom/alertmanager:v0.27.0 | 9093 | Alert routing and notifications |
| cAdvisor | gcr.io/cadvisor/cadvisor:v0.50.0 | 8080 | Container metrics |
| Node Exporter | prom/node-exporter:v1.8.2 | 9100 | Host metrics |
| Uptime Kuma | louislam/uptime-kuma:1.23.15 | 3001 | Service availability monitoring |
| Grafana OnCall | grafana/oncall:v1.9.22 | 8080 | On-call alert management |

## 🔗 Data Flow

```
Services (Docker/Containers)
    ↓
cAdvisor → Container metrics
    ↓
Prometheus → Scrapes & stores (15s interval)
    ↓
Grafana → Visualizes via dashboards
    ↓
Alertmanager → Sends alerts
    ↓
ntfy → Push notifications
    ↓
Email/Slack/Other channels

Promtail → Collects logs from:
    - Docker containers (auto-discovery)
    - System logs (/var/log/syslog)
    - Traefik access logs
    → Loki → Stores logs (7 days)
    ↓
Grafana → Queries logs via Loki data source
```

## 📈 Dashboards

The 5 dashboards are are auto-provisioned via Grafana's provisioning system:
- **Node Exporter Full** (1860) - Host metrics and CPU, memory, disk
- **Docker Container & Host Metrics** (179) - Container metrics
- **Traefik Official** (17346) - Traefik reverse proxy
- **Loki Dashboard** (13639) - Log aggregation
- **Uptime Kuma** (18278) - Service availability

All dashboards can be accessed at https://grafana.${DOMAIN}/dashboards

## 🚨 alerting

Alert rules are organized into three categories:

### Host Alerts (config/prometheus/alerts/host.yml)
- CPU > 80% for 5 minutes
- Memory > 90%
- Disk > 85%
- Disk IO anomalies

### Container Alerts (config/prometheus/alerts/containers.yml)
- Container restart > 3 times/hour
- Container OOM kills
- Health check failures

### Service Alerts (config/prometheus/alerts/services.yml)
- HTTP 5xx errors > 5%
- Response time P99 > 2s

Alert routing: Prometheus → Alertmanager → ntfy

## 🔧 Configuration

All configuration files are located in the `config/` directory:
- **Prometheus**: `config/prometheus/prometheus.yml`
- **Grafana**: `config/grafana/provisioning/`
- **Loki**: `config/loki/loki-config.yml`
- **Promtail**: `config/loki/promtail-config.yml`
- **Tempo**: `config/tempo/tempo-config.yml`
- **Alertmanager**: `config/alertmanager/alertmanager.yml`

## 📝 scripts

- **setup-observability.sh**: Main setup script
- **download-grafana-dashboards.sh**: Downloads and provisions Grafana dashboards
- **uptime-kuma-setup.sh**: Configures Uptime Kuma monitoring

## ✅ Verification

To Run the verification script to test all services:

```bash
# Check all services are running
docker-compose ps

# Test Prometheus targets
curl -f http://localhost:9090/api/v1/targets || exit 1

curl -f http://localhost:3000/api/health || exit 1

# Test Grafana
curl -f http://localhost:3000/api/health || exit 1

# Test Loki
curl -f http://localhost:3100/ready || exit 1

# Test Alertmanager
curl -f http://localhost:9093/-/healthy || exit 1

# Test Uptime Kuma
curl -f http://localhost:3001 || exit 1

# Test cAdvisor
curl -f http://localhost:8080/healthz || exit 1

# Test Node Exporter
curl -f http://localhost:9100/metrics || exit 1

echo "✅ All services are healthy!"
```

## 📚 Retention policies

```yaml
PROMETHEUS_RETENTION: 30d
LOKI_RETENTION: 7d
TEMPO_RETENTION: 72h  # 3 days
```

## 🎯 Monitoring coverage

All services expose metrics at the following endpoints:

- Prometheus: `:9090/metrics`
- Grafana: `:3000/metrics`
- Loki: `:3100/loki/api/v1/push`
- Tempo: `:3200/tempo/api/metrics`
- Alertmanager: `:9093/api/v2/alerts`
- cAdvisor: `:8080/metrics`
- Node Exporter: `:9100/metrics`
- Traefik: `:8080/metrics`
- Authentik: `:9300/metrics`
- Nextcloud: `:9205/metrics`
- Gitea: `:3000/metrics`

## 🔐 Security

- **Network isolation**: Services use internal `observability` network
- **Traefik integration**: All services behind Traefik reverse proxy with HTTPS
- **Authentik SSO**: Grafana, Prometheus, and Alertmanager support Authentik OIDC
- **No hardcoded secrets**: All passwords and tokens use environment variables
- **Read-only access**: Most services use read-only mounts (Prometheus, Grafana, Loki)
- **Data encryption at rest**: Docker volumes and encrypted at rest

## 📚 resource requirements

**Minimum:**
- 4 CPU cores
- 8GB RAM
- 50GB disk space

**Recommended:**
- 8 CPU cores
- 16GB RAM
- 100GB disk space

## 🛠️ troubleshooting

### Service won't start
```bash
docker-compose logs <service_name>
```

Common issues:
- **Prometheus scrape failures**: Check target service health
- **Grafana provisioning errors**: Verify provisioning config
- **Loki connection errors**: Check Promtail logs
- **Alertmanager not sending alerts**: Verify ntfy webhook configuration

## 📝 License

MIT

## 🤝 Contributing

Contributions welcome! See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## 📋 Verification

Run the comprehensive test script: ```bash
docker-compose -f docker-compose.test.yml up -d
sleep 5
docker-compose ps
docker-compose logs prometheus
docker-compose logs grafana
docker-compose logs l loki
docker-compose logs alertmanager
docker-compose logs cadvisor
docker-compose logs node-exporter
docker-compose logs uptime-kuma
docker-compose logs tempo

docker-compose logs oncall

# Check service health
for service in prometheus grafana loki tempo alertmanager uptime-kuma cadvisor node-exporter oncall; do
  echo "✅ $service is healthy"
done

# Check Prometheus targets
curl -s http://prometheus:9090/api/v1/targets || grep -q "up"
for target in $(cat); | echo "$target $target is is UP"
  exit 1
done
echo "❌ Some targets are not UP"

# Alert if test failures
for service in prometheus Grafana loki tempo alertmanager; do
  echo "⚠️  $service is not responding. Check logs:"
  echo "Logs:"
  docker-compose logs --tail=50 $service
  echo "WARNING: Test failures detected"
  exit 1
        fi
    done
    else
        echo "✅ All services responding"
    fi
done

done

echo ""
echo "📊 Test Report"
echo "Passed: $(date_passed -s)"
echo "Services tested: prometheus, Grafana, Loki, Tempo, Alertmanager, Uptime Kuma, cAdvisor, Node Exporter, Grafana OnCall"
echo "Failures: $failed_services"
echo ""
