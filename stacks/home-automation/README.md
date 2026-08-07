# Home Automation Stack

Complete smart home automation stack with Zigbee support and visual flow programming.

## Services

| Service | Port | Purpose |
|---------|------|---------|
| **Mosquitto** | 1883 (MQTT), 9001 (WS) | MQTT message broker |
| **Zigbee2MQTT** | 8080 | Zigbee device gateway |
| **Home Assistant** | 8123 | Smart home hub |
| **Node-RED** | 1880 | Visual flow automation |
| **ESPHome** | 6052, 6123 | ESP device firmware |

## Quick Start

```bash
# 1. Create Mosquitto users
cd stacks/home-automation
docker compose up -d mosquitto
docker compose exec mosquitto mosquitto_passwd -c /mosquitto/config/passwd admin
docker compose exec mosquitto mosquitto_passwd /mosquitto/config/passwd zigbee2mqtt
docker compose exec mosquitto mosquitto_passwd /mosquitto/config/passwd nodered

# 2. Configure Zigbee coordinator
#    Edit zigbee2mqtt/data/configuration.yaml with your coordinator settings

# 3. Start everything
docker compose up -d
```

## Why Home Assistant uses `network_mode: host`

Home Assistant requires `network_mode: host` for:
- **mDNS/UPnP device discovery** — Chromecast, AirPlay, Sonos, etc.
- **Bluetooth LE** — direct BLE scanning for sensors
- **DHCP discovery** — automatic detection of new network devices

A bridge mode alternative is provided (commented out) with documented limitations.

## Access After Startup

- Home Assistant: http://localhost:8123
- Node-RED: http://localhost:1880
- Zigbee2MQTT: http://localhost:8080
- ESPHome: http://localhost:6052

## Security

- MQTT broker is password-protected (anonymous access disabled)
- ACL rules restrict Zigbee2MQTT to its topic namespace
- Home Assistant onboarding requires initial setup
