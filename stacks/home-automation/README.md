# Home Automation Stack

Complete smart home automation: **Home Assistant** hub, **Node-RED** visual flows, **Mosquitto** MQTT broker, **Zigbee2MQTT** device gateway, and **ESPHome** firmware manager.

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| [Home Assistant](https://www.home-assistant.io/) | `ha.yourdomain.com` | Smart home hub |
| [Node-RED](https://nodered.org/) | `nodered.yourdomain.com` | Visual automation flows |
| [Mosquitto](https://mosquitto.org/) | Port 1883 (MQTT) | MQTT message broker |
| [Zigbee2MQTT](https://www.zigbee2mqtt.io/) | `zigbee.yourdomain.com` | Zigbee device gateway |
| [ESPHome](https://esphome.io/) | `esphome.yourdomain.com` | ESP device firmware |

## Architecture

```
  Zigbee Devices          ESP Devices          WiFi Devices
       │                       │                     │
       ▼                       ▼                     │
  ┌──────────┐          ┌──────────┐                 │
  │Zigbee2MQTT│          │ ESPHome  │                 │
  │  :8080   │          │  :6052   │                 │
  └─────┬────┘          └─────┬────┘                 │
        │                     │                      │
        ▼                     ▼                      ▼
  ┌──────────────────────────────────────────────────────┐
  │              Mosquitto MQTT Broker (:1883)           │
  └──────────────────────┬───────────────────────────────┘
                         │
              ┌──────────┼──────────┐
              ▼                     ▼
        ┌──────────┐          ┌──────────┐
        │   Home   │          │ Node-RED │
        │Assistant │◄────────►│  :1880   │
        │  :8123   │          └──────────┘
        │ (host)   │
        └──────────┘
```

## Network Mode: Why Host?

Home Assistant uses `network_mode: host` by default because:

1. **mDNS/Bonjour**: Required to discover devices like Chromecast, Apple TV, Sonos
2. **UPnP/SSDP**: Used by many IoT devices for auto-discovery
3. **Multicast**: Essential for device protocols that use multicast packets

### Bridge Mode Alternative

If you don't need LAN device discovery, you can switch to bridge mode by modifying the docker-compose.yml:

```yaml
# Replace network_mode: host with:
homeassistant:
  # Remove: network_mode: host
  networks:
    - proxy
    - iot
  ports:
    - "8123:8123"
```

**Bridge mode limitations:**
- No mDNS device discovery (Chromecast, Sonos, etc.)
- No UPnP/SSDP auto-discovery
- Must manually configure device IPs
- Zigbee/Z-Wave via MQTT still works normally

## Quick Start

```bash
# 1. Copy environment template
cp .env.example .env

# 2. Fill in your values
nano .env

# 3. Set up MQTT authentication
docker compose up -d mosquitto
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/password_file homeassistant your-mqtt-password
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/password_file zigbee2mqtt your-mqtt-password
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/password_file nodered your-mqtt-password
docker compose restart mosquitto

# 4. Start all services
docker compose up -d
```

## Service Configuration

### MQTT Users

Create separate MQTT users for each service:

```bash
# Add user (interactive password prompt)
docker exec -it mosquitto mosquitto_passwd /mosquitto/config/password_file username

# Add user (non-interactive)
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/password_file username password

# Delete user
docker exec mosquitto mosquitto_passwd -D /mosquitto/config/password_file username

# Restart to apply
docker compose restart mosquitto
```

### Home Assistant → MQTT

In Home Assistant, add MQTT integration:
1. Settings → Devices & Services → Add Integration → MQTT
2. Broker: `localhost` (host mode) or `mosquitto` (bridge mode)
3. Port: `1883`
4. Username: `homeassistant`
5. Password: your MQTT password

### Node-RED → MQTT

1. Open Node-RED → Settings (☰) → Manage Palette → Install `node-red-contrib-home-assistant-websocket`
2. Add MQTT broker node:
   - Server: `mosquitto`
   - Port: `1883`
   - Username: `nodered`
   - Password: your MQTT password

### Node-RED → Home Assistant

1. Install `node-red-contrib-home-assistant-websocket` in Node-RED
2. Configure HA server node:
   - Base URL: `http://homeassistant:8123` (bridge) or `http://localhost:8123` (host)
   - Access Token: Generate long-lived token in HA → Profile → Security

### Zigbee2MQTT

**USB Adapter Setup:**

1. Identify your Zigbee adapter:
   ```bash
   ls -l /dev/serial/by-id/
   ```

2. Uncomment device mapping in docker-compose.yml:
   ```yaml
   devices:
     - /dev/ttyUSB0:/dev/ttyACM0
   ```

3. Configure Zigbee2MQTT (first start creates config):
   ```yaml
   # Edit zigbee2mqtt-data volume → configuration.yaml
   mqtt:
     base_topic: zigbee2mqtt
     server: mqtt://mosquitto:1883
     user: zigbee2mqtt
     password: your-mqtt-password
   serial:
     port: /dev/ttyACM0
   frontend:
     port: 8080
   ```

**Supported adapters:** SONOFF Zigbee 3.0 USB, ConBee II, CC2531, CC2652

### ESPHome

Access the dashboard at `esphome.yourdomain.com`:

1. Click "New Device" → Enter device name
2. Choose board type (ESP32, ESP8266)
3. Edit YAML configuration
4. Compile and flash via USB or OTA

**USB flashing:** Uncomment `privileged: true` in docker-compose.yml.

## Subdomains

| Subdomain | Service |
|-----------|---------|
| `ha.yourdomain.com` | Home Assistant |
| `nodered.yourdomain.com` | Node-RED |
| `zigbee.yourdomain.com` | Zigbee2MQTT |
| `esphome.yourdomain.com` | ESPHome |

## Volumes

| Volume | Content |
|--------|---------|
| `ha-config` | Home Assistant configuration, automations, database |
| `node-red-data` | Node-RED flows, credentials, packages |
| `mosquitto-data` | MQTT persistent messages |
| `mosquitto-logs` | MQTT broker logs |
| `zigbee2mqtt-data` | Zigbee device database, configuration |
| `esphome-data` | ESPHome device configs, firmware builds |

## Troubleshooting

### Home Assistant can't discover devices

Ensure `network_mode: host` is set. Bridge mode disables mDNS/UPnP discovery.

### MQTT connection refused

1. Check Mosquitto is running: `docker logs mosquitto`
2. Verify password file exists: `docker exec mosquitto cat /mosquitto/config/password_file`
3. Test connection: `docker exec mosquitto mosquitto_sub -t '#' -u homeassistant -P your-password -C 1 -W 5`

### Zigbee2MQTT won't start

1. Check USB adapter is detected: `ls /dev/ttyUSB*` or `ls /dev/ttyACM*`
2. Check permissions: `sudo chmod 666 /dev/ttyUSB0`
3. View logs: `docker logs zigbee2mqtt`
