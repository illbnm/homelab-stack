# Enterprise Notifications Stack

A complete, production-ready notification solution featuring multi-channel delivery, message queuing, monitoring, and enterprise-grade reliability for homelabs and businesses.

## Features

### 📱 Multi-Channel Delivery
- **Gotify**: Self-hosted push notification server
- **NTFY**: Simple HTTP pub/sub notifications
- **Apprise**: 75+ notification services (Telegram, Slack, Discord, Email, SMS, etc.)
- **Webhook Support**: Custom integration endpoints

### 🔧 Advanced Features
- **Message Queuing**: Redis-backed reliable delivery
- **Priority Handling**: Critical vs normal notifications
- **Retry Logic**: Automatic retry with exponential backoff
- **Message Templates**: Dynamic content with variables
- **Rate Limiting**: Protect against abuse

### 📊 Monitoring and Analytics
- **Delivery Tracking**: Success/failure rates per channel
- **Performance Metrics**: Latency and throughput monitoring
- **Grafana Dashboards**: Custom visualization (optional)
- **Alerting**: Self-monitoring with Prometheus/Alertmanager

### ⚡ Production Ready
- Health checks and automatic restarts
- Resource limits and optimization
- Secure authentication and encryption
- Backup and recovery procedures

## Quick Start

### Prerequisites
- Docker and Docker Compose
- 2GB RAM minimum, 4GB recommended
- Persistent storage for message history

### Installation

1. **Clone or copy the notifications stack**
   ```bash
   git clone <repository-url>
   cd notifications
   ```

2. **Configure environment variables**
   ```bash
   cp .env.notifications.example .env.notifications
   # Edit .env.notifications with your settings
   ```

3. **Run the setup script**
   ```bash
   chmod +x scripts/setup-notifications.sh
   ./scripts/setup-notifications.sh
   ```

4. **Verify the installation**
   ```bash
   ./scripts/validate-notifications.sh
   ```

## Service Details

### Gotify Notification Server
- **Purpose**: Central push notification server
- **Web UI**: http://<server-ip>:8080
- **API**: REST API for sending/receiving notifications
- **Features**: User management, application tokens, priority levels
- **Configuration**: `config/notification-server/`

### NTFY
- **Purpose**: Simple HTTP-based pub/sub notifications
- **Web UI**: http://<server-ip>:8081
- **Features**: Topics, authentication, file attachments
- **Use Cases**: System alerts, CI/CD notifications, IoT messages
- **Configuration**: `config/ntfy/`

### Apprise-API
- **Purpose**: Gateway to 75+ notification services
- **API**: http://<server-ip>:8000
- **Supported Services**: Telegram, Slack, Discord, Email, SMS, Pushover, etc.
- **Features**: Tag-based routing, templating, bulk sending
- **Configuration**: `config/apprise/`

### Webhook Receiver
- **Purpose**: Custom webhook endpoint for integrations
- **Endpoint**: http://<server-ip>:8082/webhook/<channel>
- **Features**: Signature verification, rate limiting, logging
- **Configuration**: `config/webhook/`

### Optional Services
- **Grafana**: http://<server-ip>:3002 (visualizations)
- **Prometheus**: http://<server-ip>:9091 (metrics)
- **AlertManager**: http://<server-ip>:9093 (alert routing)
- **Redis**: <server-ip>:6379 (message queue)
- **PostgreSQL**: <server-ip>:5432 (persistent storage)

## Configuration

### Environment Variables
Key variables in `.env.notifications`:

| Variable | Description | Default |
|----------|-------------|---------|
| `NOTIFICATION_ADMIN_PASSWORD` | Gotify admin password | `changeme` |
| `NTFY_BASE_URL` | NTFY server URL | `http://localhost:8081` |
| `WEBHOOK_SECRET` | Webhook signature secret | `webhooksecret` |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | (empty) |
| `SLACK_WEBHOOK_URL` | Slack webhook URL | (empty) |

### Channel Configuration
1. **Telegram**:
   ```yaml
   telegram://{BotToken}/{ChatID}
   ```

2. **Slack**:
   ```yaml
   slack://{WebhookToken}
   ```

3. **Email**:
   ```yaml
   mailto://user:pass@gmail.com
   ```

4. **Discord**:
   ```yaml
   discord://{WebhookID}/{WebhookToken}
   ```

### Security Configuration
1. **Change all passwords** in `.env.notifications`
2. **Set up SSL certificates** for HTTPS
3. **Configure API keys** for external services
4. **Implement rate limiting** to prevent abuse
5. **Enable authentication** for all endpoints

### Performance Tuning
Adjust based on your load:

```bash
# CPU limits
NOTIFICATION_SERVER_CPU_LIMIT=1.0
NTFY_CPU_LIMIT=0.5
APPRISE_CPU_LIMIT=0.5

# Memory limits
NOTIFICATION_SERVER_MEMORY_LIMIT=512M
NTFY_MEMORY_LIMIT=256M
APPRISE_MEMORY_LIMIT=256M

# Queue settings
QUEUE_WORKERS=4
QUEUE_MAX_RETRIES=3
QUEUE_RETRY_DELAY=30
```

## Usage Examples

### Sending Notifications

#### Via Gotify API
```bash
curl -X POST "http://localhost:8080/message" \
  -H "X-Gotify-Key: YOUR_APP_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Server is down!",
    "title": "Alert",
    "priority": 10,
    "extras": {
      "client::notification": {
        "click": {"url": "https://status.example.com"}
      }
    }
  }'
```

#### Via NTFY
```bash
# Simple message
curl -d "Backup completed successfully" "http://localhost:8081/backups"

# With title and priority
curl -H "Title: System Alert" \
     -H "Priority: high" \
     -d "CPU usage at 95%" \
     "http://localhost:8081/alerts"
```

#### Via Apprise
```bash
curl -X POST "http://localhost:8000/notify" \
  -H "Content-Type: application/json" \
  -d '{
    "urls": "slack://{WebhookToken}/#alerts",
    "title": "Deployment Complete",
    "body": "Version 2.0 deployed to production",
    "tag": "deployments"
  }'
```

#### Via Webhook
```bash
curl -X POST "http://localhost:8082/webhook/system" \
  -H "Content-Type: application/json" \
  -H "X-Signature: $(echo -n '{"alert":"high"}' | openssl sha256 -hmac 'your-secret')" \
  -d '{"alert": "high", "message": "Disk space critical"}'
```

### Receiving Notifications

#### Subscribe to NTFY topics
```bash
# Using curl
curl -s "http://localhost:8081/alerts/json"

# Using websockets
wscat -c "ws://localhost:8081/alerts/ws"
```

#### Gotify WebSocket
```javascript
// JavaScript client
const ws = new WebSocket('ws://localhost:8080/stream');
ws.onmessage = (event) => {
  const notification = JSON.parse(event.data);
  console.log('New notification:', notification);
};
```

### Integration Examples

#### With Prometheus Alertmanager
```yaml
# alertmanager.yml
receivers:
  - name: 'notifications'
    webhook_configs:
      - url: 'http://notification-server/message?token=YOUR_TOKEN'
        send_resolved: true
```

#### With Home Assistant
```yaml
# configuration.yaml
notify:
  - name: gotify
    platform: rest
    resource: http://localhost:8080/message
    method: POST
    headers:
      "X-Gotify-Key": "YOUR_APP_TOKEN"
    message_param_name: message
    title_param_name: title
    data:
      priority: 5
```

#### With CI/CD Pipelines
```yaml
# GitHub Actions
- name: Send notification
  run: |
    curl -X POST "http://${{ secrets.NOTIFICATION_SERVER }}/message" \
      -H "X-Gotify-Key: ${{ secrets.GOTIFY_TOKEN }}" \
      -d '{"message": "Build ${{ github.run_number }} completed", "title": "CI/CD", "priority": 1}'
```

## Monitoring and Maintenance

### Health Checks
Run periodic checks:
```bash
# Manual check
./scripts/validate-notifications.sh

# Automated check (add to cron)
*/15 * * * * /path/to/notifications/scripts/validate-notifications.sh >> /var/log/notifications-health.log
```

### Logs
- **Docker logs**: `docker-compose -f docker-compose.notifications.yml logs -f`
- **Application logs**: Check individual container logs
- **Access logs**: Monitor for security events
- **Message logs**: Delivery success/failure tracking

### Backups
1. **Configuration backup**:
   ```bash
   tar -czf notifications-backup-$(date +%Y%m%d).tar.gz config/ data/
   ```

2. **Database backup** (if using PostgreSQL):
   ```bash
   docker exec postgres-notifications pg_dump -U notifications notifications > notifications-db-$(date +%Y%m%d).sql
   ```

3. **Message history backup**:
   - Export from Gotify admin interface
   - Backup NTFY cache database
   - Archive Apprise configuration

### Updates
1. **Update Docker images**:
   ```bash
   docker-compose -f docker-compose.notifications.yml pull
   docker-compose -f docker-compose.notifications.yml up -d
   ```

2. **Test updates** in staging environment
3. **Monitor** for breaking changes in release notes
4. **Update configurations** as needed

## Troubleshooting

### Common Issues

#### Notifications Not Delivering
- **Check**: Service logs and connectivity
- **Solution**: Verify channel configurations, API keys, network access

#### High Resource Usage
- **Check**: `docker stats` and monitoring dashboards
- **Solution**: Adjust resource limits, optimize queue settings, add more workers

#### Authentication Failures
- **Check**: Logs for authentication errors
- **Solution**: Verify credentials, check token expiration, review access controls

#### Message Queue Backlog
- **Check**: Redis queue length and worker status
- **Solution**: Increase workers, optimize message processing, review rate limits

### Debug Commands
```bash
# Check service status
docker-compose -f docker-compose.notifications.yml ps

# View logs for specific service
docker logs notification-server --tail 50 -f

# Test notification delivery
curl -X POST "http://localhost:8080/message" \
  -H "X-Gotify-Key: test" \
  -d '{"message": "Test", "title": "Test", "priority": 1}'

# Check Redis queue
docker exec redis-notifications redis-cli KEYS "*"

# Monitor network connectivity
docker exec notification-server ping -c 3 8.8.8.8

# Check database connections
docker exec postgres-notifications psql -U notifications -c "\l"
```

## Integration

### With Existing Systems
1. **Monitoring systems**: Prometheus, Nagios, Zabbix
2. **CI/CD pipelines**: GitHub Actions, GitLab CI, Jenkins
3. **Automation platforms**: Home Assistant, Node-RED, IFTTT
4. **Business systems**: CRM, ticketing, support platforms

### With Monitoring Systems
1. **Prometheus metrics** from all services
2. **Grafana dashboards** for visualization
3. **Alerting integration** with existing alert managers
4. **Log aggregation** with ELK or Loki

### With Backup Systems
- **Configuration backup**: Regular backup of `config/` and `.env.notifications`
- **Database backup**: Scheduled database dumps
- **Message archive**: Long-term storage of important notifications

### With Automation Tools
- **Ansible**: Use Docker modules for deployment
- **Terraform**: Manage as Docker resources
- **Kubernetes**: Convert docker-compose to K8s manifests

## Security Best Practices

1. **Network Security**
   - Use VLAN segmentation for notification traffic
   - Implement firewall rules to restrict access
   - Use VPN for remote management
   - Regular security updates

2. **Access Control**
   - Strong passwords and API keys
   - 2FA where available
   - Regular access reviews
   - Principle of least privilege

3. **Data Protection**
   - Encrypt sensitive configuration
   - Secure API key storage
   - Message encryption for sensitive content
   - Secure backup storage

4. **Monitoring**
   - Monitor for unauthorized access attempts
   - Regular security audits
   - Incident response plan
   - Log monitoring and alerting

## Performance Optimization

### For High Volume
1. **Use Redis queue** for message buffering
2. **Increase worker processes**
3. **Optimize database queries**
4. **Use connection pooling**

### For Many Channels
1. **Parallelize channel delivery**
2. **Cache channel configurations**
3. **Use bulk sending where possible**
4. **Monitor channel rate limits**

### For Low Latency
1. **Use in-memory caching**
2. **Optimize network paths**
3. **Reduce message processing overhead**
4. **Use efficient serialization**

### For High Availability
1. **Use external databases** (PostgreSQL)
2. **Implement monitoring and alerting**
3. **Regular backups and tested recovery**
4. **Redundant infrastructure**

## Contributing

### Adding Features
1. Fork the repository
2. Create a feature branch
3. Implement with tests
4. Update documentation
5. Submit pull request

### Reporting Issues
1. Check existing issues
2. Provide detailed steps
3. Include logs and configs
4. Suggest solutions

### Feature Requests
1. Describe use case
2. Consider complexity
3. Discuss with maintainers
4. Consider contributing

## License

[Specify your license here]

## Support

- **Documentation**: This README and inline comments
- **Issues**: GitHub issue tracker
- **Community**: [Link to community forum]
- **Commercial Support**: [Contact if applicable]

---

*Last updated: $(date)*
*Version: 1.0.0*