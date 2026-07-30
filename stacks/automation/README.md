# Home Automation Stack

Smart home automation suite: Home Assistant, Node-RED, Mosquitto MQTT, Zigbee2MQTT, and ESPHome.

## Services

| Service | Image | URL |
|---------|-------|-----|
| Home Assistant | `ghcr.io/home-assistant/home-assistant:2024.9.3` | `http://${HOST_IP}:8123` |
| Node-RED | `nodered/node-red:4.0.3` | `https://flow.${DOMAIN}` |
| Mosquitto | `eclipse-mosquitto:2.0.19` | `mqtt://${HOST_IP}:1883` |
| Zigbee2MQTT | `koenkk/zigbee2mqtt:1.40.2` | `https://zigbee.${DOMAIN}` |
| ESPHome | `ghcr.io/esphome/esphome:2024.9.3` | `https://esphome.${DOMAIN}` |

## Quick Start

```bash
cp .env.example .env
nano .env  # Set domain, Zigbee device path, MQTT passwords

# Generate Mosquitto passwords
docker run -it eclipse-mosquitto:2.0.19 mosquitto_passwd -c /tmp/passwd homeassistant
# Repeat for zigbee2mqtt and nodered users, then copy to ./mosquitto/passwd

# Start stack
docker compose up -d
```

## Home Assistant Network Mode

Home Assistant uses `network_mode: host` because:

1. **mDNS Discovery**: Discovers IoT devices (Chromecast, Apple TV, smart speakers) via multicast DNS
2. **UPnP/SSDP**: Some devices require broadcast discovery which doesn't work in bridge mode
3. **Bluetooth**: Native BLE discovery requires host network access

### Bridge Mode Alternative

If host networking is unavailable, uncomment the bridge mode config in `docker-compose.yml`.
**Limitations**: No mDNS, no UPnP, no Bluetooth, reduced IoT device discovery.

## DNS Records

| Hostname | Service |
|----------|---------|
| `home.${DOMAIN}` | Home Assistant (bridge mode only) |
| `flow.${DOMAIN}` | Node-RED |
| `zigbee.${DOMAIN}` | Zigbee2MQTT |
| `esphome.${DOMAIN}` | ESPHome |

## Mosquitto Security

- Anonymous access disabled
- Password authentication required
- WebSocket listener on port 9001
- TLS config template included (commented out)

### Generate Passwords

```bash
# Generate password file
docker run -it eclipse-mosquitto:2.0.19 mosquitto_passwd -c /tmp/passwd homeassistant
docker run -it eclipse-mosquitto:2.0.19 mosquitto_passwd /tmp/passwd zigbee2mqtt
docker run -it eclipse-mosquitto:2.0.19 mosquitto_passwd /tmp/passwd nodered
# Copy /tmp/passwd to ./mosquitto/passwd
```

## Zigbee2MQTT Setup

1. Plug in your Zigbee adapter (CC2531, Sonoff, ConBee, etc.)
2. Set `ZIGBEE_DEVICE` in `.env` to the serial path
3. Start the stack — Zigbee2MQTT will auto-detect the adapter
4. Open `https://zigbee.${DOMAIN}` to pair devices

## Home Assistant MQTT Integration

1. Settings → Devices & Services → Add Integration → MQTT
2. Broker: `mosquitto` (or host IP if using host network)
3. Port: `1883`
4. Username: `homeassistant`
5. Password: (from your Mosquitto passwd file)

## Node-RED MQTT

1. Install `node-red-contrib-mqtt` if not included
2. MQTT broker: `mqtt://mosquitto:1883`
3. Use credentials from Mosquitto passwd file