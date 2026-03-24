# Home Automation Stack

Smart home hub, automation, and IoT device management for HomeLab.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Home Assistant | 2024.11.3 | `ha.<DOMAIN>` | Smart home hub |
| Node-RED | 3.1.14 | `nodered.<DOMAIN>` | Flow-based automation |
| Mosquitto | 2.0.20 | `localhost:1883` | MQTT broker |
| Zigbee2MQTT | 1.41.0 | `zigbee.<DOMAIN>` | Zigbee device management |

## Architecture

```
Zigbee devices ──→ Zigbee2MQTT ──→ Mosquitto (MQTT broker)
                                      ↓
                                  Home Assistant ←──→ Node-RED
                                      ↓
                                  Automations & dashboards
```

## Prerequisites

- Base infrastructure stack running (Traefik + proxy network)
- Zigbee USB dongle (for Zigbee2MQTT) — e.g. Sonoff Zigbee 3.0
- If using Zigbee2MQTT, update device path in config

## Quick Start

```bash
cd stacks/home-automation
cp .env.example .env
docker compose up -d
```

## Configuration

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain |
| `TZ` | ✅ | Timezone |
| `ZIGBEE_DEVICE` | ❌ | USB dongle path, e.g. `/dev/ttyUSB0` |

## Post-Deploy Setup

1. **Home Assistant**: Open `https://ha.<DOMAIN>` — create admin account
2. **Node-RED**: Open `https://nodered.<DOMAIN>` — install HA palette
3. **Mosquitto**: Runs with anonymous access by default — add auth in `mosquitto.conf` for production
4. **Zigbee2MQTT**: Open `https://zigbee.<DOMAIN>` — pair devices via UI

## Health Checks

```bash
docker compose ps
```
