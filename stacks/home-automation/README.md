# Enterprise Home Automation Stack

A complete, production-ready smart home solution featuring Home Assistant, Zigbee2MQTT, MQTT broker, Node-RED, and comprehensive monitoring for advanced home automation.

## Features

### 🏠 Complete Smart Home Platform
- **Home Assistant**: Central automation hub with 2000+ integrations
- **Zigbee2MQTT**: Support for 1000+ Zigbee devices without proprietary hubs
- **Mosquitto MQTT**: Robust message broker for device communication
- **Node-RED**: Visual automation and integration tool

### 🔧 Advanced Automation
- **Multi-protocol support**: Zigbee, Z-Wave (via adapter), WiFi, Bluetooth
- **Visual automation**: Node-RED flows for complex logic
- **Custom firmware**: ESPHome for ESP32/ESP8266 devices
- **Python automation**: AppDaemon for advanced automations

### 📊 Monitoring and Analytics
- **Performance monitoring**: Container and system metrics
- **Device tracking**: Real-time device status and history
- **Energy monitoring**: Power usage tracking and optimization
- **Grafana dashboards**: Customizable visualizations (optional)

### ⚡ Production Ready
- Health checks and automatic restarts
- Resource limits and optimization
- Secure authentication and encryption
- Backup and recovery procedures

## Quick Start

### Prerequisites
- Docker and Docker Compose
- 4GB RAM minimum, 8GB recommended
- Zigbee USB adapter (optional but recommended)
- Persistent storage for databases

### Installation

1. **Clone or copy the home automation stack**
   ```bash
   git clone <repository-url>
   cd home-automation
   ```

2. **Configure environment variables**
   ```bash
   cp .env.home-automation.example .env.home-automation
   # Edit .env.home-automation with your settings
   ```

3. **Run the setup script**
   ```bash
   chmod +x scripts/setup-home-automation.sh
   ./scripts/setup-home-automation.sh
   ```

4. **Verify the installation**
   ```bash
   ./scripts/validate-home-automation.sh
   ```

## Service Details

### Home Assistant
- **Purpose**: Central automation hub and dashboard
- **Web UI**: http://<server-ip>:8123
- **Features**: 2000+ integrations, dashboards, automations
- **Configuration**: `config/homeassistant/`

### Zigbee2MQTT
- **Purpose**: Connect Zigbee devices to MQTT/Home Assistant
- **Web UI**: http://<server-ip>:8080
- **Supported devices**: 1000+ Zigbee devices
- **Configuration**: `config/zigbee2mqtt/configuration.yaml`

### Mosquitto MQTT
- **Purpose**: Message broker for device communication
- **Port**: 1883 (MQTT), 9001 (WebSockets)
- **Security**: User authentication and ACL
- **Configuration**: `config/mosquitto/`

### Node-RED
- **Purpose**: Visual automation and integration
- **Web UI**: http://<server-ip>:1880
- **Features**: Flow-based programming, 3000+ nodes
- **Configuration**: `config/nodered/`

### Optional Services
- **ESPHome**: http://<server-ip>:6052 (device firmware)
- **AppDaemon**: http://<server-ip>:5050 (Python automations)
- **Grafana**: http://<server-ip>:3001 (visualizations)
- **Prometheus**: http://<server-ip>:9090 (metrics)

## Configuration

### Environment Variables
Key variables in `.env.home-automation`:

| Variable | Description | Default |
|----------|-------------|---------|
| `TIMEZONE` | System timezone | `UTC` |
| `ZIGBEE2MQTT_PORT` | Zigbee adapter path | `/dev/ttyUSB0` |
| `MQTT_USER` | MQTT username | `homeassistant` |
| `MQTT_PASSWORD` | MQTT password | `changeme` |
| `HOMEASSISTANT_LATITUDE` | Location latitude | `0.0` |
| `HOMEASSISTANT_LONGITUDE` | Location longitude | `0.0` |

### Security Configuration
1. **Change all passwords** in `.env.home-automation`
2. **Set up proper MQTT authentication**
3. **Configure SSL certificates** for remote access
4. **Restrict network access** to management interfaces
5. **Regular security updates**

### Performance Tuning
Adjust based on your hardware:

```bash
# CPU limits
HOMEASSISTANT_CPU_LIMIT=2.0
ZIGBEE2MQTT_CPU_LIMIT=0.5
MOSQUITTO_CPU_LIMIT=0.3
NODERED_CPU_LIMIT=0.5

# Memory limits
HOMEASSISTANT_MEMORY_LIMIT=2G
ZIGBEE2MQTT_MEMORY_LIMIT=512M
MOSQUITTO_MEMORY_LIMIT=256M
NODERED_MEMORY_LIMIT=512M
```

## Usage Examples

### Initial Setup
1. Access Home Assistant at `http://<server-ip>:8123`
2. Complete the setup wizard
3. Configure your location and units
4. Create your first user account

### Adding Zigbee Devices
1. Enable pairing in Zigbee2MQTT Web UI
2. Put your device in pairing mode
3. Device will appear in Home Assistant
4. Configure device entities and automations

### Creating Automations
1. **Using Home Assistant**:
   - Go to Settings → Automations & Scenes
   - Create visual automations
   - Test and activate

2. **Using Node-RED**:
   - Access `http://<server-ip>:1880`
   - Install Home Assistant nodes
   - Create visual flows
   - Deploy and monitor

### MQTT Integration
1. **Publish messages**:
   ```bash
   mosquitto_pub -h localhost -t "home/livingroom/light" -m "on"
   ```

2. **Subscribe to topics**:
   ```bash
   mosquitto_sub -h localhost -t "home/#"
   ```

3. **Home Assistant MQTT discovery**:
   - Configure devices in `configuration.yaml`
   - Use MQTT auto-discovery for supported devices

## Monitoring and Maintenance

### Health Checks
Run periodic checks:
```bash
# Manual check
./scripts/validate-home-automation.sh

# Automated check (add to cron)
*/15 * * * * /path/to/home-automation/scripts/validate-home-automation.sh >> /var/log/ha-health.log
```

### Logs
- **Docker logs**: `docker-compose -f docker-compose.home-automation.yml logs -f`
- **Home Assistant logs**: `data/homeassistant/home-assistant.log`
- **Zigbee2MQTT logs**: Check container logs
- **MQTT logs**: `data/mosquitto/log/mosquitto.log`

### Backups
1. **Configuration backup**:
   ```bash
   tar -czf home-automation-backup-$(date +%Y%m%d).tar.gz config/ data/homeassistant/
   ```

2. **Database backup** (if using MariaDB/InfluxDB):
   ```bash
   docker exec mariadb-home mysqldump -u root -p homeassistant > homeassistant-db-$(date +%Y%m%d).sql
   ```

3. **Automated backups**:
   - Use the built-in Home Assistant backup
   - Schedule regular backups to external storage

### Updates
1. **Update Docker images**:
   ```bash
   docker-compose -f docker-compose.home-automation.yml pull
   docker-compose -f docker-compose.home-automation.yml up -d
   ```

2. **Home Assistant updates**:
   - Backup before updating
   - Check breaking changes
   - Test in staging if possible

## Troubleshooting

### Common Issues

#### Home Assistant Won't Start
- **Check**: `docker logs homeassistant`
- **Solution**: Check configuration syntax, permissions, dependencies

#### Zigbee Devices Not Connecting
- **Check**: Zigbee2MQTT logs and adapter permissions
- **Solution**: Verify adapter compatibility, check USB permissions, update firmware

#### MQTT Connection Issues
- **Check**: Mosquitto logs and network connectivity
- **Solution**: Verify credentials, firewall rules, service health

#### High Resource Usage
- **Check**: `docker stats` and monitoring dashboards
- **Solution**: Adjust resource limits, optimize automations, add more RAM

### Debug Commands
```bash
# Check service status
docker-compose -f docker-compose.home-automation.yml ps

# View specific service logs
docker logs homeassistant --tail 50 -f

# Test MQTT connectivity
docker exec mosquitto mosquitto_sub -h localhost -t "\$SYS/#" -v

# Check Zigbee network
docker exec zigbee2mqtt zigbee2mqtt bridge-info

# Monitor resource usage
docker stats --no-stream

# Restart services
docker-compose -f docker-compose.home-automation.yml restart homeassistant
```

## Integration

### With Existing Systems
1. **Network integration**: Configure VLANs for IoT devices
2. **External services**: Integrate with cloud services (weather, calendar, etc.)
3. **Voice assistants**: Connect with Google Assistant, Amazon Alexa
4. **Mobile access**: Set up remote access via VPN or proxy

### With Monitoring Systems
1. **Prometheus metrics** from Node Exporter and cAdvisor
2. **Grafana dashboards** for visualization
3. **Alerting** for service failures
4. **Log aggregation** with ELK or Loki

### With Backup Systems
- **Configuration backup**: Regular backup of `config/` and `data/`
- **Database backup**: Scheduled database dumps
- **State backup**: Home Assistant snapshot exports

### With Automation Tools
- **Ansible**: Use Docker modules for deployment
- **Terraform**: Manage as Docker resources
- **Kubernetes**: Convert docker-compose to K8s manifests

## Security Best Practices

1. **Network Security**
   - IoT devices on isolated VLAN
   - Firewall rules to restrict access
   - VPN for remote access
   - Regular security updates

2. **Access Control**
   - Strong passwords for all services
   - 2FA for Home Assistant
   - Regular access reviews
   - Principle of least privilege

3. **Data Protection**
   - Encrypted backups
   - Secure remote access
   - Data minimization
   - Privacy-focused integrations

4. **Monitoring**
   - Monitor for unauthorized access
   - Regular security audits
   - Incident response plan
   - Log monitoring and alerting

## Performance Optimization

### For Large Installations
1. **Use MariaDB** instead of SQLite for Home Assistant recorder
2. **Enable InfluxDB** for long-term data storage
3. **Optimize automations** to reduce overhead
4. **Use efficient integrations**

### For Limited Resources
1. **Disable non-essential integrations**
2. **Reduce history retention**
3. **Use lighter frontend themes**
4. **Optimize database queries**

### For High Availability
1. **Use external databases** (MariaDB/InfluxDB)
2. **Implement monitoring and alerting**
3. **Regular backups and tested recovery**
4. **Redundant power and network**

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
- **Community**: Home Assistant forums, Discord
- **Commercial Support**: [Contact if applicable]

---

*Last updated: $(date)*
*Version: 1.0.0*