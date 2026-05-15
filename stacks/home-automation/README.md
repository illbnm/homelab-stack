# Home Automation Stack

Home Assistant + Node-RED + Zigbee2MQTT.

## Services

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Home Assistant | 2024.10 | `ha.${DOMAIN}` | Home automation |
| Node-RED | 4.0.2 | `nodered.${DOMAIN}` | Flow automation |
| Zigbee2MQTT | 1.41.0 | `zigbee.${DOMAIN}` | Zigbee bridge |

## Quick Start

```bash
# MQTT broker must be running first
docker compose -f stacks/home-automation/docker-compose.yml up -d
```

Note: Zigbee2MQTT requires USB passthrough (`/dev/ttyACM0` or `/dev/ttyUSB0`).
