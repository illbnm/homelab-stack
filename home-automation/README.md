# Home Automation Stack

A comprehensive home automation setup using Home Assistant, Node-RED, and Zigbee2MQTT for smart home device integration and automation.

## Prerequisites

### Network Configuration - Host Mode Required

**IMPORTANT**: This setup requires your router to be in **Host Mode** (not Bridge Mode) for proper mDNS and UPnP discovery functionality.

#### Why Host Mode is Required:
- **mDNS Discovery**: Home Assistant uses multicast DNS for automatic device discovery
- **UPnP/SSDP**: Many smart devices use UPnP for network announcement and discovery
- **Local Network Services**: Zigbee2MQTT, Node-RED, and Home Assistant need to communicate on the local network

#### Bridge Mode Limitations:
- Disables router's DHCP server and local network management
- Prevents mDNS multicast traffic routing
- Blocks UPnP device announcements
- Results in failed device discovery and integration issues

### Bridge Mode Alternative Setup:
If you must use Bridge Mode, you'll need:
1. A separate router/switch in Host Mode behind your ISP modem
2. Manual IP configuration for all devices
3. Static routes for inter-VLAN communication
4. mDNS reflector/repeater configuration

## Quick Start

### 1. Initial Setup
```bash
# Clone the repository
git clone <repository-url>
cd home-automation

# Start all services
docker-compose up -d
```

### 2. Access Services
- **Home Assistant**: http://localhost:8123
- **Node-RED**: http://localhost:1880
- **Zigbee2MQTT**: http://localhost:8080

### 3. Network Verification
```bash
# Test mDNS discovery
avahi-browse -rt _http._tcp

# Check UPnP devices
upnpc -l

# Verify multicast routing
ip route show | grep 224.0.0.0
```

## Service Configuration

### Home Assistant
1. Complete initial setup wizard at http://localhost:8123
2. Enable advanced mode in user profile
3. Install HACS (Home Assistant Community Store)
4. Configure integrations for your devices

### Node-RED
1. Access Node-RED at http://localhost:1880
2. Install Home Assistant palette: `node-red-contrib-home-assistant-websocket`
3. Configure Home Assistant connection using long-lived access token
4. Import automation flows from `flows/` directory

### Zigbee2MQTT
1. Connect Zigbee coordinator to host system
2. Update `zigbee2mqtt/configuration.yaml` with your coordinator device path
3. Access frontend at http://localhost:8080
4. Pair devices using permit join functionality

## Device Integration Guide

### Zigbee Devices
1. Enable permit join in Zigbee2MQTT
2. Put device in pairing mode
3. Device automatically appears in Home Assistant via MQTT discovery
4. Configure device name and area in Home Assistant

### WiFi Smart Devices
1. Ensure devices are on same network as Home Assistant
2. Use Home Assistant integrations:
   - **TP-Link Kasa**: Auto-discovered via UPnP
   - **Philips Hue**: Auto-discovered via mDNS
   - **Sonoff/Tasmota**: MQTT or auto-discovery
   - **Tuya/Smart Life**: Tuya integration or Local Tuya

### Network Discovery Troubleshooting
If devices aren't discovered automatically:

1. **Check Router Mode**:
   ```bash
   # Verify DHCP is active (Host Mode indicator)
   nmap -sn 192.168.1.0/24
   ```

2. **Verify mDNS**:
   ```bash
   # Install avahi tools
   sudo apt install avahi-utils
   
   # Browse for Home Assistant
   avahi-browse -rt _home-assistant._tcp
   
   # Browse for other services
   avahi-browse -rt _http._tcp
   ```

3. **Check Firewall**:
   ```bash
   # Allow mDNS
   sudo ufw allow 5353/udp
   
   # Allow UPnP
   sudo ufw allow 1900/udp
   ```

4. **Manual Device Addition**:
   - Use device IP addresses directly
   - Configure static IP reservations in router
   - Add devices via Home Assistant integrations page

## Automation Examples

### Basic Lighting Automation (Node-RED)
```json
[{"id":"motion-light","type":"ha-entity","name":"Motion Sensor","server":"home-assistant","entityid":"binary_sensor.living_room_motion"},{"id":"light-control","type":"ha-call-service","name":"Toggle Light","server":"home-assistant","service_domain":"light","service":"toggle","entityId":"light.living_room"}]
```

### Zigbee Device Automation (Home Assistant YAML)
```yaml
automation:
  - alias: "Zigbee Button Press"
    trigger:
      platform: device
      device_id: "your_button_device_id"
      domain: "zha"
      type: "remote_button_short_press"
    action:
      service: light.toggle
      target:
        entity_id: light.bedroom
```

## Security Configuration

### Network Isolation
- Consider VLAN separation for IoT devices
- Use firewall rules to restrict device communication
- Enable WPA3 security on WiFi networks

### Home Assistant Security
- Enable two-factor authentication
- Use strong passwords and long-lived access tokens
- Configure trusted networks and IP filtering
- Regular backups of configuration

### MQTT Security
- Change default Mosquitto passwords
- Enable TLS encryption for external access
- Use ACL (Access Control Lists) for device permissions

## Backup and Maintenance

### Automated Backups
```bash
# Create backup script
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
tar -czf "backup_${DATE}.tar.gz" \
  homeassistant/ \
  zigbee2mqtt/data/ \
  nodered/data/
```

### Regular Maintenance
- Monitor container logs: `docker-compose logs -f`
- Update containers monthly: `docker-compose pull && docker-compose up -d`
- Check disk space and clean old logs
- Test automations and device connectivity

### Monitoring
- Use Home Assistant system monitor integration
- Set up alerts for device offline status
- Monitor network performance and latency

## Troubleshooting

### Common Issues
1. **Devices not discovered**: Verify Host Mode and network configuration
2. **Zigbee pairing fails**: Check coordinator connection and interference
3. **Node-RED connection issues**: Verify Home Assistant token and URL
4. **Performance issues**: Monitor resource usage and optimize automations

### Log Locations
- Home Assistant: `homeassistant/home-assistant.log`
- Zigbee2MQTT: `docker-compose logs zigbee2mqtt`
- Node-RED: `docker-compose logs nodered`

### Reset Procedures
```bash
# Reset Home Assistant (keeps config)
docker-compose restart homeassistant

# Reset Zigbee network (CAUTION: Unpairs all devices)
rm zigbee2mqtt/data/database.db

# Reset Node-RED flows
rm nodered/data/flows.json
```

## Advanced Features

### Voice Control Integration
- Amazon Alexa via Nabu Casa or manual skill
- Google Assistant via Nabu Casa or manual actions
- Local voice control with Rhasspy or Home Assistant Voice

### Mobile Access
- Home Assistant mobile app with presence detection
- VPN access for secure remote control
- Nabu Casa for cloud access without port forwarding

### External Integrations
- Weather services (OpenWeatherMap, AccuWeather)
- Calendar integration (Google Calendar, CalDAV)
- Notification services (Telegram, Discord, email)
- Energy monitoring and solar integration

## Support and Resources

### Documentation
- [Home Assistant Documentation](https://www.home-assistant.io/docs/)
- [Node-RED Documentation](https://nodered.org/docs/)
- [Zigbee2MQTT Documentation](https://www.zigbee2mqtt.io/)

### Community
- Home Assistant Community Forum
- Node-RED Community Forum
- Reddit: r/homeassistant, r/nodered
- Discord servers for real-time help

### Hardware Recommendations
- **Zigbee Coordinators**: ConBee II, Sonoff Zigbee 3.0, SkyConnect
- **Zigbee Devices**: Aqara, IKEA Trådfri, Sengled, Philips Hue
- **Host Hardware**: Raspberry Pi 4, Intel NUC, dedicated server