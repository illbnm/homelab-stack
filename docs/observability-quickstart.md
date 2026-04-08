# 🚀 Observability Stack Quick Start Guide

Get your complete observability stack running in under 10 minutes!

## ⚡ Prerequisites

- Docker Engine 24+ installed
- Docker Compose v2.20+ installed
- 4GB RAM minimum (8GB recommended)
- 50GB free disk space for data retention
- Domain name (optional, but recommended)

## 📋 Quick Setup Checklist

- [ ] 1. Clone repository
- [ ] 2. Configure environment variables
- [ ] 3. Start base infrastructure (Traefik)
- [ ] 4. Start SSO provider (Authentik)
- [ ] 5. Configure OAuth for Grafana
- [ ] 6. Start monitoring stack
- [ ] 7. Verify deployment
- [ ] 8. Access dashboards

---

## 🎯 Step-by-Step Guide

### Step 1: Clone Repository

```bash
git clone https://github.com/yourusername/homelab-stack.git
cd homelab-stack
```

### Step 2: Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit with your values
nano .env
```

**Minimum Required Variables**:

```bash
# General
TZ=Asia/Shanghai                    # Your timezone
DOMAIN=yourdomain.com               # Your domain
ACME_EMAIL=you@example.com          # Let's Encrypt email

# Traefik
TRAEFIK_DASHBOARD_USER=admin
TRAEFIK_DASHBOARD_PASSWORD_HASH=    # Generate: echo $(htpasswd -nb admin password) | sed -e s/\$/\$\$/g

# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=your_secure_password

# Authentik (for SSO)
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)
AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -base64 32)
AUTHENTIK_REDIS_PASSWORD=$(openssl rand -base64 32)
AUTHENTIK_BOOTSTRAP_TOKEN=$(openssl rand -base64 32)
AUTHENTIK_DOMAIN=auth.yourdomain.com
```

### Step 3: Start Base Infrastructure

```bash
# Start Traefik (reverse proxy)
./scripts/stack-manager.sh start base

# Wait for Traefik to be ready
sleep 10

# Verify Traefik is running
docker ps | grep traefik
```

### Step 4: Start Authentik (SSO)

```bash
# Start Authentik stack
./scripts/stack-manager.sh start sso

# Wait for Authentik to initialize (2-3 minutes)
echo "Waiting for Authentik to start..."
sleep 120

# Verify Authentik is running
docker ps | grep authentik
```

**Access Authentik**:
1. Navigate to https://auth.yourdomain.com/if/flow/initial-setup/
2. Set admin password
3. Log in to Authentik admin

### Step 5: Configure Grafana OAuth

**In Authentik Admin UI**:

1. Navigate to **Applications → Providers**
2. Click **Create**
3. Select **OAuth2/OpenID Provider**
4. Configure:
   - Name: `Grafana`
   - Authorization flow: `default-provider-authorization-explicit-consent`
   - Client type: `Confidential`
   - Redirect URIs: `https://grafana.yourdomain.com/login/generic_oauth`
   - Signing Key: Select or create RSA key
5. Click **Finish**
6. **Copy Client ID and Client Secret**

**Update .env**:

```bash
# Add OAuth credentials
GRAFANA_OAUTH_CLIENT_ID=<paste_client_id>
GRAFANA_OAUTH_CLIENT_SECRET=<paste_client_secret>
```

**Create Authentik Groups**:

1. Navigate to **Directory → Groups**
2. Create group: `Grafana Admins`
3. Create group: `Grafana Editors`
4. Add your user to `Grafana Admins`

**Create Application**:

1. Navigate to **Applications → Applications**
2. Click **Create**
3. Configure:
   - Name: `Grafana`
   - Slug: `grafana`
   - Provider: `Grafana` (select the provider you created)
   - Launch URL: `https://grafana.yourdomain.com`
4. Click **Finish**

### Step 6: Start Monitoring Stack

```bash
# Start monitoring stack
./scripts/stack-manager.sh start monitoring

# Wait for services to start (1-2 minutes)
echo "Waiting for monitoring services to start..."
sleep 90

# Verify all services are running
docker compose -f stacks/monitoring/docker-compose.yml ps
```

### Step 7: Verify Deployment

```bash
# Run verification script
cd stacks/monitoring
../../scripts/verify-observability.sh
```

Expected output:
```
✅ Observability stack is properly configured!
```

### Step 8: Access Dashboards

**Grafana**:
- URL: https://grafana.yourdomain.com
- Login: Use Authentik SSO
- Navigate to Dashboards → Browse → HomeLab

**Pre-loaded Dashboards**:
1. Node Exporter Full - System metrics
2. Docker Container & Host Metrics - Container metrics
3. Traefik Official - Reverse proxy metrics
4. Loki Dashboard - Log aggregation metrics
5. Uptime Kuma - Uptime monitoring

**Other Services**:
- Prometheus: https://prometheus.yourdomain.com
- Alertmanager: https://alertmanager.yourdomain.com (requires Authentik)
- Uptime Kuma: https://status.yourdomain.com
- OnCall (optional): https://oncall.yourdomain.com

---

## 🔧 Post-Deployment Configuration

### Configure Uptime Kuma

1. Access https://status.yourdomain.com
2. Create admin account
3. Add monitors:
   - Your services (Traefik, Grafana, etc.)
   - External endpoints (google.com, etc.)
4. Configure notifications (Discord, Slack, Telegram, etc.)

### Configure Alert Notifications

Edit `config/alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: default
    # Add your notification channels
    slack_configs:
      - api_url: https://hooks.slack.com/services/YOUR/WEBHOOK
        channel: '#alerts'
    # Or use Discord webhook
    webhook_configs:
      - url: https://discord.com/api/webhooks/YOUR_WEBHOOK
```

Reload Alertmanager:
```bash
curl -X POST http://localhost:9093/-/reload
```

### Add Custom Metrics

To monitor custom applications:

1. **Add Prometheus target**:

Edit `config/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: my-app
    static_configs:
      - targets: [my-app:9090]
```

2. **Reload Prometheus**:
```bash
curl -X POST http://localhost:9090/-/reload
```

### Add Custom Log Sources

Edit `config/loki/promtail-config.yml`:

```yaml
scrape_configs:
  - job_name: my-app-logs
    static_configs:
      - targets: [localhost]
        labels:
          job: my-app
          __path__: /var/log/myapp/*.log
```

Restart Promtail:
```bash
docker compose -f stacks/monitoring/docker-compose.yml restart promtail
```

---

## 📊 Quick Wins

### View System Metrics

1. Log in to Grafana
2. Navigate to **Dashboards → Browse → HomeLab**
3. Open **Node Exporter Full**
4. Explore CPU, memory, disk, network metrics

### View Container Metrics

1. Open **Docker Container & Host Metrics** dashboard
2. Select container from dropdown
3. View CPU, memory, network, disk I/O

### Query Logs in Grafana

1. Navigate to **Explore**
2. Select **Loki** data source
3. Run query: `{job="docker-containers"} |= "error"`
4. View container logs with error messages

### Set Up Alert

1. Navigate to **Alerting → Alert rules**
2. Click **New alert rule**
3. Configure:
   - Name: `High Memory Usage`
   - Query: `(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100`
   - Condition: `WHEN last() OF query(A) IS ABOVE 90`
   - Evaluate every: `1m`
   - For: `5m`
4. Save and enable

### Create Custom Dashboard

1. Click **+ → New Dashboard**
2. Add visualization:
   - Select Prometheus data source
   - Query: `rate(node_cpu_seconds_total{mode!="idle"}[5m])`
3. Add panel, configure legend
4. Save dashboard to HomeLab folder

---

## 🐛 Common Issues & Fixes

### Issue: Traefik not routing to Grafana

**Solution**:
```bash
# Check Traefik logs
docker logs traefik

# Verify container labels
docker inspect grafana | grep -A 20 Labels

# Check Traefik routers
curl http://localhost:8080/api/http/routers
```

### Issue: Prometheus not scraping targets

**Solution**:
```bash
# Check target status
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Verify network connectivity
docker exec prometheus ping node-exporter

# Check Prometheus logs
docker logs prometheus
```

### Issue: Grafana SSO not working

**Solution**:
1. Verify OAuth credentials in .env
2. Check redirect URI matches exactly
3. Restart Grafana: `docker compose -f stacks/monitoring/docker-compose.yml restart grafana`
4. Check Grafana logs: `docker logs grafana`

### Issue: No logs in Loki

**Solution**:
```bash
# Check Promtail logs
docker logs promtail

# Verify Docker socket access
docker exec promtail ls -la /var/run/docker.sock

# Check Loki health
curl http://localhost:3100/ready
```

### Issue: Alerts not firing

**Solution**:
```bash
# Check alert rules
curl http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | select(.state == "firing")'

# Test alert expression
curl 'http://localhost:9090/api/v1/query?query=up == 0'

# Check Alertmanager
curl http://localhost:9093/api/v2/alerts
```

---

## 📚 Next Steps

1. **Customize Dashboards**: Modify pre-loaded dashboards or create new ones
2. **Add More Targets**: Monitor additional services and applications
3. **Configure Alerts**: Set up alerts for your specific needs
4. **Integrate Apps**: Add logging and tracing to your applications
5. **Set Up Backups**: Configure regular backups of Prometheus and Grafana data
6. **Performance Tuning**: Adjust retention periods and resource limits

---

## 🔗 Useful Links

- **Full Documentation**: `docs/observability.md`
- **Verification Script**: `scripts/verify-observability.sh`
- **Configuration Files**: `config/`
- **Docker Compose**: `stacks/monitoring/docker-compose.yml`

---

## 💡 Pro Tips

1. **Start Simple**: Begin with default settings, customize later
2. **Monitor Gradually**: Add services one at a time
3. **Use Labels**: Consistent labeling makes queries easier
4. **Test Alerts**: Verify alerts work before relying on them
5. **Document Changes**: Keep track of custom configurations
6. **Regular Maintenance**: Review and clean up unused dashboards/queries
7. **Resource Limits**: Set memory limits to prevent resource exhaustion

---

## 🎉 Success!

Your observability stack is now running! You have:

- ✅ Centralized metrics collection with Prometheus
- ✅ Beautiful dashboards with Grafana
- ✅ Log aggregation with Loki
- ✅ Distributed tracing with Tempo
- ✅ Alert management with Alertmanager
- ✅ Uptime monitoring with Uptime Kuma
- ✅ Container metrics with cAdvisor
- ✅ System metrics with Node Exporter
- ✅ SSO integration with Authentik

**Total Setup Time**: ~10 minutes

Enjoy monitoring your homelab! 🚀

---

*Need help? Check `docs/observability.md` for detailed documentation*
