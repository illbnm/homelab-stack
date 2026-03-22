# 🏠 Home Automation Stack

> Complete smart home automation platform with Home Assistant, Node-RED, MQTT, Zigbee, and ESPHome.

## 🎯 Bounty: [#7](../../issues/7) - $130 USDT

## 📋 Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| **Home Assistant** | `ghcr.io/home-assistant/home-assistant:2024.9.3` | 8123 | Smart home hub |
| **Node-RED** | `nodered/node-red:4.0.3` | 1880 | Visual flow automation |
| **Mosquitto** | `eclipse-mosquitto:2.0.19` | 1883/9001 | MQTT broker |
| **Zigbee2MQTT** | `koenkk/zigbee2mqtt:1.40.2` | 8080 | Zigbee gateway |
| **ESPHome** | `ghcr.io/esphome/esphome:2024.9.3` | 6052 | ESP device firmware |

## 🚀 Quick Start

```bash
# 1. Copy environment example
cp .env.example .env

# 2. Edit environment variables
nano .env

# 3. Copy Mosquitto configuration
cp mosquitto.conf.example config/mosquitto/mosquitto.conf

# 4. Start the stack
cd /home/zhaog/.openclaw/workspace/data/bounty-projects/homelab-stack
docker compose -f stacks/home-automation/docker-compose.yml up -d

# 5. Check status
docker compose -f stacks/home-automation/docker-compose.yml ps
```

## ⚙️ Configuration

### Environment Variables

```bash
# Domain
DOMAIN=example.com

# Timezone
TZ=Asia/Shanghai

# Mosquitto
MQTT_USERNAME=homeassistant
MQTT_PASSWORD=your-secure-mqtt-password
```

### Access URLs

After deployment:

- **Home Assistant**: `http://<host-ip>:8123` (or `https://ha.${DOMAIN}` with bridge mode)
- **Node-RED**: `https://nodered.${DOMAIN}`
- **Zigbee2MQTT**: `https://zigbee.${DOMAIN}`
- **ESPHome**: `https://esphome.${DOMAIN}`

## 📝 Service Details

### Home Assistant

**⚠️ Network Mode: HOST**

Home Assistant uses `network_mode: host` for critical functionality:

- **mDNS discovery** - Finds Chromecast, AirPlay, Sonos devices
- **UPnP/SSDP** - Discovers smart TVs, lights, sensors
- **Broadcast traffic** - Required for many IoT protocols

**Bridge Mode Alternative:**

If host mode is not available, use the commented bridge mode configuration. However:

- ❌ mDNS discovery won't work
- ❌ UPnP devices won't be found automatically
- ✅ Web UI still accessible via Traefik
- ✅ Manual device configuration possible

**USB Devices:**

Home Assistant has access to `/dev/ttyUSB*` for:
- Zigbee USB adapters (if not using Zigbee2MQTT container)
- Z-Wave USB sticks
- ESP devices for flashing

### Node-RED

**Features:**
- Visual flow-based programming
- Pre-installed Home Assistant nodes
- MQTT integration
- Dashboard UI for controls

**Access:**
- Editor: `https://nodered.${DOMAIN}`
- Default password: Set on first login
- Flows stored in: `/data` volume

**Common Flows:**
- Motion sensor → Turn on lights
- Temperature threshold → Send notification
- Time-based → Arm/disarm alarm

### Mosquitto

**Configuration:**
- Port 1883: MQTT TCP
- Port 9001: MQTT over WebSocket
- Anonymous access: Disabled
- Persistence: Enabled

**Security:**
```bash
# Set password (first time)
docker exec mosquitto mosquitto_passwd -c /mosquitto/config/pwfile homeassistant

# Add additional users
docker exec mosquitto mosquitto_passwd /mosquitto/config/pwfile node-red
```

**Topics:**
- `homeassistant/` - HA state updates
- `zigbee2mqtt/` - Zigbee device data
- `esphome/` - ESP device telemetry

### Zigbee2MQTT

**Purpose:** Connect Zigbee devices to MQTT without proprietary hubs.

**Supported Adapters:**
- Texas Instruments CC2652/CC2652P
- Silicon Labs EFR32 (Sonoff, Slaesh)
- ConBee II/III (Dresden Elektronik)
- Zigbee Star

**Setup:**
1. Plug in Zigbee USB adapter
2. Access web UI at `https://zigbee.${DOMAIN}`
3. Configure adapter path (auto-detected)
4. Set MQTT server: `mqtt://mosquitto:1883`
5. Pair devices by pressing reset button

**Frontend Integration:**
- Home Assistant discovers Zigbee2MQTT automatically
- All devices appear as native HA entities
- Supports OTA updates for many devices

### ESPHome

**Purpose:** Flash and manage ESP32/ESP8266 devices.

**Features:**
- Web-based configuration editor
- OTA firmware updates
- Native Home Assistant integration
- Pre-built firmware for common devices

**Common Devices:**
- Sonoff basic/mini
- Shelly switches
- Custom ESP32 sensors
- WLED light controllers

**Workflow:**
1. Create new device in ESPHome UI
2. Configure sensors/switches
3. Flash via USB or web installer
4. Device auto-discovers to Home Assistant

## 🔧 Mosquitto Configuration

Create `config/mosquitto/mosquitto.conf`:

```conf
# Listener configuration
listener 1883
listener 9001
protocol websockets

# Persistence
persistence true
persistence_location /mosquitto/data/

# Logging
log_dest file /mosquitto/log/mosquitto.log
log_type error
log_type warning
log_type notice
log_type information

# Security
allow_anonymous false
password_file /mosquitto/config/pwfile

# ACL (optional, for advanced setups)
# acl_file /mosquitto/config/acl
```

## ✅ Verification Checklist

- [ ] Home Assistant accessible on port 8123
- [ ] Home Assistant completes setup wizard
- [ ] Node-RED editor accessible
- [ ] Node-RED can connect to MQTT
- [ ] Mosquitto accepts authenticated connections
- [ ] Zigbee2MQTT web UI accessible
- [ ] Zigbee adapter detected (if plugged in)
- [ ] ESPHome dashboard accessible
- [ ] All services auto-restart on failure
- [ ] Home Assistant discovers other stack services

## 🐛 Troubleshooting

### Home Assistant Device Discovery Not Working

```bash
# Verify host network mode
docker inspect homeassistant | grep NetworkMode

# Should show: "NetworkMode": "host"
# If not, edit docker-compose.yml and restart
```

### Zigbee Adapter Not Detected

```bash
# Check USB devices
ls -l /dev/ttyUSB*

# Verify permissions
docker exec zigbee2mqtt ls -l /dev/ttyUSB*

# If permission denied, add user to dialout group
sudo usermod -a -G dialout $USER
# Then reboot or logout/login
```

### Mosquitto Connection Refused

```bash
# Check logs
docker logs mosquitto

# Verify password file exists
docker exec mosquitto ls -l /mosquitto/config/pwfile

# Reset password if needed
docker exec mosquitto mosquitto_passwd -c /mosquitto/config/pwfile homeassistant
docker restart mosquitto
```

### Node-RED Flows Not Saving

```bash
# Check volume mount
docker inspect node-red | grep -A5 Mounts

# Verify disk space
df -h /var/lib/docker/volumes/node-red-data
```

## 📚 Related Stacks

- [Network](../network/) - DNS and VPN infrastructure
- [Monitoring](../monitoring/) - Track home automation metrics
- [Notifications](../notifications/) - Send alerts from automations

## 🏠 Example Automations

### Motion-Activated Lights

```yaml
# In Node-RED or Home Assistant automation
trigger: binary_sensor.motion_sensor
action:
  - service: light.turn_on
    target:
      entity_id: light.living_room
```

### Temperature Alert

```yaml
trigger:
  platform: numeric_state
  entity_id: sensor.bedroom_temperature
  above: 28
action:
  - service: notify.mobile_app
    data:
      message: "Bedroom is hot! Consider turning on AC."
```

### Good Night Scene

```yaml
alias: "Good Night"
trigger:
  platform: state
  entity_id: input_boolean.good_night
  to: "on"
action:
  - service: light.turn_off
    target:
      entity_id: light.all_lights
  - service: cover.close_all
  - service: alarm_control_panel.alarm_arm_night
    target:
      entity_id: alarm_control_panel.home_alarm
```

---

*Bounty: $130 USDT | Status: In Progress*
