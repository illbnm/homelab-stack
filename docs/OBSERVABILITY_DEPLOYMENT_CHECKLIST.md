# 📋 Observability Stack Deployment Checklist

Use this checklist to ensure your observability stack is properly deployed and configured.

## ✅ Pre-Deployment Checklist

### Infrastructure Requirements
- [ ] Docker Engine 24+ installed
- [ ] Docker Compose v2.20+ installed
- [ ] Minimum 4GB RAM available (8GB recommended)
- [ ] Minimum 50GB disk space available
- [ ] Linux OS (Ubuntu 22.04+ recommended) or macOS
- [ ] Root/sudo access for Docker operations

### Network Requirements
- [ ] Domain name configured (optional but recommended)
- [ ] DNS records configured:
  - [ ] grafana.yourdomain.com
  - [ ] prometheus.yourdomain.com
  - [ ] status.yourdomain.com
  - [ ] auth.yourdomain.com (for Authentik)
- [ ] Ports 80 and 443 accessible from internet (for Let's Encrypt)
- [ ] Firewall configured to allow Docker traffic

### Repository Setup
- [ ] Repository cloned: `git clone https://github.com/yourusername/homelab-stack.git`
- [ ] Working directory: `cd homelab-stack`
- [ ] Scripts are executable: `chmod +x scripts/*.sh`

---

## 🔧 Configuration Checklist

### Environment Variables
- [ ] Copied .env.example to .env
- [ ] Set TZ (timezone)
- [ ] Set DOMAIN (your domain name)
- [ ] Set ACME_EMAIL (Let's Encrypt email)
- [ ] Set TRAEFIK_DASHBOARD_USER
- [ ] Set TRAEFIK_DASHBOARD_PASSWORD_HASH
- [ ] Set GRAFANA_ADMIN_USER
- [ ] Set GRAFANA_ADMIN_PASSWORD
- [ ] Set AUTHENTIK_SECRET_KEY
- [ ] Set AUTHENTIK_POSTGRES_PASSWORD
- [ ] Set AUTHENTIK_REDIS_PASSWORD
- [ ] Set AUTHENTIK_BOOTSTRAP_TOKEN
- [ ] Set AUTHENTIK_DOMAIN

### Optional Configuration
- [ ] Set PROMETHEUS_RETENTION (default: 30d)
- [ ] Set LOKI_RETENTION (default: 7d)
- [ ] Set TEMPO_RETENTION (default: 72h)
- [ ] Set ONCALL_SECRET_KEY (if using OnCall)
- [ ] Configure alert notification webhooks

---

## 🚀 Deployment Checklist

### Step 1: Base Infrastructure
- [ ] Started base stack: `./scripts/stack-manager.sh start base`
- [ ] Traefik container running: `docker ps | grep traefik`
- [ ] Traefik dashboard accessible: https://traefik.yourdomain.com
- [ ] Traefik healthy: `curl http://localhost:8080/ping`

### Step 2: SSO Provider
- [ ] Started SSO stack: `./scripts/stack-manager.sh start sso`
- [ ] Authentik containers running: `docker ps | grep authentik`
- [ ] Authentik accessible: https://auth.yourdomain.com
- [ ] Admin account created
- [ ] Authentik healthy: `curl http://localhost:9000/-/health/ready`

### Step 3: OAuth Configuration
- [ ] Created OAuth2 provider in Authentik
- [ ] Provider name: Grafana
- [ ] Client type: Confidential
- [ ] Redirect URI: https://grafana.yourdomain.com/login/generic_oauth
- [ ] Copied Client ID to .env as GRAFANA_OAUTH_CLIENT_ID
- [ ] Copied Client Secret to .env as GRAFANA_OAUTH_CLIENT_SECRET
- [ ] Created Grafana Admins group in Authentik
- [ ] Created Grafana Editors group in Authentik
- [ ] Added user to Grafana Admins group
- [ ] Created Grafana application in Authentik
- [ ] Application linked to Grafana provider

### Step 4: Monitoring Stack
- [ ] Started monitoring stack: `./scripts/stack-manager.sh start monitoring`
- [ ] All services running: `docker compose -f stacks/monitoring/docker-compose.yml ps`
  - [ ] prometheus
  - [ ] grafana
  - [ ] loki
  - [ ] promtail
  - [ ] tempo
  - [ ] alertmanager
  - [ ] cadvisor
  - [ ] node-exporter
  - [ ] uptime-kuma
- [ ] Optional: grafana-oncall running

---

## 🔍 Verification Checklist

### Service Health
- [ ] Prometheus healthy: `curl http://localhost:9090/-/healthy`
- [ ] Grafana healthy: `curl http://localhost:3000/api/health`
- [ ] Loki ready: `curl http://localhost:3100/ready`
- [ ] Tempo ready: `curl http://localhost:3200/ready`
- [ ] Alertmanager healthy: `curl http://localhost:9093/-/healthy`
- [ ] Uptime Kuma responding: `curl http://localhost:3001`

### Prometheus Targets
- [ ] View targets: https://prometheus.yourdomain.com/targets
- [ ] prometheus target UP
- [ ] node-exporter target UP
- [ ] cadvisor target UP
- [ ] traefik target UP (if running)
- [ ] loki target UP
- [ ] tempo target UP
- [ ] uptime-kuma target UP
- [ ] grafana target UP
- [ ] alertmanager target UP

### Grafana Data Sources
- [ ] Access Grafana: https://grafana.yourdomain.com
- [ ] Login with Authentik SSO works
- [ ] Prometheus data source configured
- [ ] Loki data source configured
- [ ] Tempo data source configured
- [ ] Can query Prometheus metrics
- [ ] Can query Loki logs
- [ ] Can query Tempo traces

### Grafana Dashboards
- [ ] Dashboards accessible in HomeLab folder
- [ ] Node Exporter Full dashboard loads
- [ ] Docker Container & Host Metrics dashboard loads
- [ ] Traefik Official dashboard loads
- [ ] Loki dashboard loads
- [ ] Uptime Kuma dashboard loads
- [ ] Dashboards show data (not empty)

### Alert Rules
- [ ] View rules: https://prometheus.yourdomain.com/rules
- [ ] homelab.yml rules loaded
- [ ] containers.yml rules loaded
- [ ] services.yml rules loaded
- [ ] No configuration errors

### Log Collection
- [ ] Promtail positions file exists: `docker exec promtail ls /tmp/positions.yaml`
- [ ] Loki has labels: `curl http://localhost:3100/loki/api/v1/labels`
- [ ] Docker container logs visible in Grafana Explore
- [ ] System logs visible in Grafana Explore

### Uptime Kuma
- [ ] Access Uptime Kuma: https://status.yourdomain.com
- [ ] Admin account created
- [ ] At least one monitor configured
- [ ] Monitor status shows as "Up"

---

## 📊 Post-Deployment Checklist

### Initial Configuration
- [ ] Created Uptime Kuma admin account
- [ ] Added monitors for critical services
- [ ] Configured notification channels in Uptime Kuma
- [ ] Tested alert notifications
- [ ] Customized Grafana dashboards (optional)
- [ ] Set up additional alert rules (optional)

### Security
- [ ] Changed default passwords
- [ ] Enabled HTTPS (via Traefik + Let's Encrypt)
- [ ] SSO configured and working
- [ ] No anonymous access enabled
- [ ] Firewall rules reviewed

### Backups
- [ ] Configured backup for Prometheus data
- [ ] Configured backup for Grafana data
- [ ] Tested backup restoration procedure
- [ ] Backup schedule set up (cron job)

### Documentation
- [ ] Read docs/observability.md
- [ ] Read docs/observability-quickstart.md
- [ ] Bookmarked key URLs:
  - [ ] Grafana
  - [ ] Prometheus
  - [ ] Alertmanager
  - [ ] Uptime Kuma

---

## 🧪 Testing Checklist

### Functionality Tests
- [ ] Can query Prometheus metrics in Grafana
- [ ] Can view logs in Grafana Explore
- [ ] Dashboards show real-time data
- [ ] Alerts fire when conditions met
- [ ] Alert notifications received
- [ ] Uptime Kuma detects service failures

### Stress Tests
- [ ] Tested with high metric cardinality
- [ ] Tested with high log volume
- [ ] Verified resource limits are appropriate
- [ ] Tested service restart recovery
- [ ] Verified data persists after restart

### Integration Tests
- [ ] SSO login works for Grafana
- [ ] Role mapping works (Admin, Editor, Viewer)
- [ ] Traefik routing to all services works
- [ ] HTTPS certificates valid
- [ ] Cross-service queries work (e.g., logs + metrics)

---

## 📈 Performance Checklist

### Resource Usage
- [ ] Prometheus memory usage < 2GB
- [ ] Grafana memory usage < 512MB
- [ ] Loki memory usage < 1GB
- [ ] Tempo memory usage < 512MB
- [ ] Overall system memory usage < 80%

### Query Performance
- [ ] Prometheus queries complete in < 5s
- [ ] Grafana dashboards load in < 10s
- [ ] Loki log queries complete in < 5s
- [ ] No query timeouts

### Data Retention
- [ ] Prometheus retention working (30 days)
- [ ] Loki retention working (7 days)
- [ ] Tempo retention working (72 hours)
- [ ] Disk space monitored

---

## 🎯 Verification Script

Run the automated verification script:

```bash
cd stacks/monitoring
../../scripts/verify-observability.sh
```

Expected result: **All tests PASS**

---

## 🚨 Common Issues

### Services Not Starting
- Check Docker logs: `docker compose logs <service>`
- Verify .env file has all required variables
- Check port conflicts: `netstat -tulpn | grep <port>`
- Verify network connectivity

### SSO Not Working
- Verify OAuth credentials in .env
- Check redirect URI matches exactly
- Verify Authentik is running
- Check Grafana logs: `docker logs grafana`

### No Metrics/Data
- Wait 5-10 minutes for data collection
- Check Prometheus targets are UP
- Verify Prometheus is scraping
- Check time ranges in Grafana

### Alerts Not Firing
- Verify alert rules loaded
- Test alert expression in Prometheus UI
- Check Alertmanager configuration
- Verify notification channels

---

## 📞 Support

If you encounter issues:

1. Check documentation: `docs/observability.md`
2. Run verification script: `scripts/verify-observability.sh`
3. Check service logs: `docker compose logs <service>`
4. Review troubleshooting section in docs
5. Open GitHub issue with logs and configuration

---

## ✅ Completion

Once all items are checked:

- [ ] All services running and healthy
- [ ] All verification tests passing
- [ ] Dashboards accessible and showing data
- [ ] Alerts configured and tested
- [ ] Backups configured
- [ ] Documentation reviewed

**🎉 Congratulations! Your observability stack is fully deployed and operational!**

---

*Last Updated: 2026-04-08*
