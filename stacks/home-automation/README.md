# Home Automation Stack

Smart home automation with Zigbee support and visual flow programming.

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| Home Assistant | `http://host:8123` | Smart home hub |
| Node-RED | `https://nodered.${DOMAIN}` | Visual flow editor |
| Mosquitto | `internal:1883` | MQTT broker |
| Zigbee2MQTT | `https://zigbee.${DOMAIN}` | Zigbee device gateway |
| ESPHome | `https://esphome.${DOMAIN}` | ESP firmware manager |

## Quick Start

```bash
cd stacks/home-automation
docker compose up -d
```

## Network Mode

Home Assistant uses `network_mode: host` for mDNS/UPnP device discovery.
This means it's accessible at `http://<server-ip>:8123` directly.

## Mosquitto Setup

1. Create password file:
```bash
docker exec mosquitto mosquitto_passwd -c /mosquitto/config/passwd homeassistant
docker exec mosquitto mosquitto_passwd /mosquitto/config/passwd nodered
docker exec mosquitto mosquitto_passwd /mosquitto/config/passwd zigbee2mqtt
```

2. Restart mosquitto:
```bash
docker restart mosquitto
```

## Zigbee2MQTT

1. Connect your Zigbee adapter (CC2531, Sonoff, etc.)
2. Uncomment the `devices` section in docker-compose.yml
3. Set your adapter path (usually `/dev/ttyUSB0` or `/dev/ttyACM0`)

## Node-RED + Home Assistant

Install the `node-red-contrib-home-assistant-websocket` palette in Node-RED to connect to Home Assistant.
