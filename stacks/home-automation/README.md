# Home Automation Stack

Smart home automation hub with Zigbee device support, visual flow automation, and MQTT message brokering.

## Services

| Service | Image | URL | Purpose |
|---------|-------|-----|---------|
| Home Assistant | `ghcr.io/home-assistant/home-assistant:2024.9.3` | `http://<host>:8123` | Smart home hub |
| Node-RED | `nodered/node-red:4.0.3` | `https://nodered.${DOMAIN}` | Visual flow automation |
| Mosquitto | `eclipse-mosquitto:2.0.19` | port 1883 | MQTT broker |
| Zigbee2MQTT | `koenkk/zigbee2mqtt:1.40.2` | `https://zigbee.${DOMAIN}` | Zigbee device gateway |
| ESPHome | `ghcr.io/esphome/esphome:2024.9.3` | `https://esphome.${DOMAIN}` | ESP device firmware |

## Why Home Assistant Uses `network_mode: host`

Home Assistant **must** run in host network mode to enable:
- **mDNS / Zeroconf** — auto-discovery of Chromecast, Apple TV, Philips Hue, etc.
- **SSDP / UPnP** — discovery of routers, smart TVs, media players
- **DHCP-based discovery** — some integrations require raw network access

Docker bridge networks block mDNS broadcasts (multicast 224.0.0.251). Without host mode, you must manually configure each device's IP address and lose auto-discovery entirely.

**Bridge mode alternative** is provided in `docker-compose.yml` as commented-out config. Use it only if you don't need auto-discovery and want strict network isolation.

## Quick Start

```bash
cd stacks/home-automation
cp .env.example .env
nano .env  # fill in DOMAIN, MQTT_PASSWORD, ZIGBEE_DEVICE

# Start core services (no Zigbee hardware needed)
docker compose up -d homeassistant mosquitto node-red

# With Zigbee coordinator:
docker compose up -d

# Setup MQTT authentication
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/passwd homeassistant ${MQTT_PASSWORD}
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/passwd zigbee2mqtt ${MQTT_PASSWORD}
docker restart mosquitto
```

## Configuration

### Mosquitto MQTT Authentication

The default config requires password authentication. On first deploy:

```bash
# Create password file entries
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/passwd homeassistant <password>
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/passwd zigbee2mqtt <password>
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/passwd nodered <password>
docker restart mosquitto
```

### Home Assistant MQTT Integration

In Home Assistant → Settings → Devices & Services → Add Integration → MQTT:
- Broker: `localhost` (host network mode) or `mosquitto` (bridge mode)
- Port: `1883`
- Username: `homeassistant`
- Password: your `MQTT_PASSWORD`

### Zigbee2MQTT Setup

1. Plug in your Zigbee coordinator USB stick
2. Find the device path: `ls /dev/serial/by-id/` (use stable path)
3. Set `ZIGBEE_DEVICE` in `.env`
4. Start zigbee2mqtt: `docker compose up -d zigbee2mqtt`
5. Open the frontend at `https://zigbee.${DOMAIN}`
6. Enable join mode to pair devices

### Node-RED Home Assistant Integration

Install the `node-red-contrib-home-assistant-websocket` package:

```bash
docker exec node-red npm install node-red-contrib-home-assistant-websocket
docker restart node-red
```

Then in Node-RED: Add a `home-assistant` server node pointing to `http://homeassistant:8123` (bridge mode) or `http://localhost:8123` (host mode).

## Troubleshooting

**Home Assistant can't find local devices:**
- Confirm `network_mode: host` is set (default)
- Check that the host firewall allows mDNS (UDP 5353)

**Zigbee2MQTT won't start:**
- Check `ZIGBEE_DEVICE` matches actual USB path
- Grant access: `sudo chmod a+rw /dev/ttyUSB0`
- Check logs: `docker logs zigbee2mqtt`

**Mosquitto authentication failure:**
- Verify passwd file has entries: `docker exec mosquitto cat /mosquitto/config/passwd`
- Regenerate: `docker exec mosquitto mosquitto_passwd -b /mosquitto/config/passwd <user> <pass>`

**ESPHome can't reach ESP devices:**
- ESPHome needs to be on the same network segment as your ESP devices
- For host network mode: use `network_mode: host` for ESPHome too (edit compose)
