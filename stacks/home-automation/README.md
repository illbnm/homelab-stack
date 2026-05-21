# Home Automation Stack

Smart home automation for HomeLab Stack — home control, flow automation, IoT messaging, and Zigbee device management.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Home Assistant | 2024.11.3 | `ha.<DOMAIN>` | Smart home platform |
| Node-RED | 3.1.14 | `nodered.<DOMAIN>` | Flow-based automation editor |
| Mosquitto | 2.0.20 | `:1883` | MQTT message broker |
| Zigbee2MQTT | 1.41.0 | `zigbee.<DOMAIN>` | Zigbee device coordinator |

## Architecture

```
IoT Devices (Zigbee sensors, lights, switches)
    │
    ▼
[Zigbee2MQTT] ── MQTT ──► [Mosquitto :1883]
                               │
                    ┌──────────┼──────────┐
                    ▼                     ▼
            [Home Assistant]       [Node-RED]
            ha.<DOMAIN>            nodered.<DOMAIN>
```

## Quick Start

```bash
cd stacks/base && docker compose up -d
cd ../home-automation
ln -sf ../../.env .env
docker compose up -d
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | — | Base domain |
| `TZ` | No | `Asia/Shanghai` | Timezone |

### Home Assistant Setup

1. Visit `https://ha.<DOMAIN>`
2. Create account (first run)
3. Install integrations: Settings → Devices & Services → Add Integration
4. Key integrations: MQTT (connect to `mosquitto:1883`), Zigbee (via Z2M)

### Zigbee2MQTT Setup

1. Plug a Zigbee coordinator USB dongle into the host
2. Pass USB device: add `devices: - /dev/ttyUSB0:/dev/ttyACM0` to zigbee2mqtt volumes
3. Visit `https://zigbee.<DOMAIN>`
4. Permit join → pair devices → configure

### Node-RED Setup

1. Visit `https://nodered.<DOMAIN>`
2. Install palette: `node-red-contrib-home-assistant-websocket`
3. Configure HA connection: `http://homeassistant:8123`
4. Build automation flows

## USB Device Passthrough

For Zigbee coordinator, add to `docker-compose.yml`:

```yaml
zigbee2mqtt:
  devices:
    - /dev/ttyUSB0:/dev/ttyACM0
```

Or with `docker compose`:
```bash
docker compose run -d --device=/dev/ttyUSB0 zigbee2mqtt
```

## Health Check

```bash
docker compose ps --format "table {{.Name}}\t{{.Status}}"
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| HA not starting | First run takes time; check `ha-config` volume permissions |
| Zigbee2MQTT can't find dongle | Ensure USB device is passed through; check `dmesg` for device path |
| MQTT connection refused | Mosquitto needs `mosquitto.conf` to allow anonymous/connections |
| Node-RED can't reach HA | Use container name `homeassistant:8123` not localhost |
| Zigbee devices not pairing | Check coordinator firmware; move coordinator away from USB 3.0 ports |
