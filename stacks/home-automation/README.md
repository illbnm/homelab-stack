# Home Automation Stack

Complete smart home automation stack with Zigbee device support and visual flow orchestration.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Home Assistant | `ghcr.io/home-assistant/home-assistant:2024.9.3` | 8123 (host) | Smart home hub |
| Node-RED | `nodered/node-red:4.0.3` | 1880 | Visual flow editor |
| Mosquitto | `eclipse-mosquitto:2.0.19` | 1883 | MQTT Broker |
| Zigbee2MQTT | `koenkk/zigbee2mqtt:1.40.2` | 8080 | Zigbee device gateway |
| ESPHome | `ghcr.io/esphome/esphome:2024.9.3` | 6052 | ESP device firmware |

## Quick Start

```bash
cp .env.example .env
# Edit .env — set DOMAIN, MQTT_USER, MQTT_PASS

# Create initial Mosquitto password file
docker compose run --rm mosquitto sh -c \
  "mosquitto_passwd -c -b /mosquitto/config/passwd ${MQTT_USER} ${MQTT_PASS}"
# Note: the passwd file is mounted at runtime via ./config/mosquitto/passwd

docker compose up -d
```

### USB Zigbee dongle

If you have a Zigbee coordinator (e.g. Sonoff ZBDongle-E/P), pass it to Zigbee2MQTT:

```yaml
# Add to zigbee2mqtt service in docker-compose.yml:
devices:
  - /dev/ttyACM0:/dev/ttyACM0
```

Then verify in Zigbee2MQTT web UI at `https://zigbee.${DOMAIN}`.

## Why `network_mode: host` for Home Assistant?

Home Assistant uses **host networking** because:

1. **mDNS discovery** — HA discovers devices (Chromecast, AirPlay, printers) via multicast DNS, which doesn't work across Docker bridge networks
2. **UPnP/SSDP** — Some devices (smart TVs, media players) are found via SSDP, which requires host-level broadcast access
3. **Bluetooth** — Bluetooth integration needs direct host bus access

### Bridge mode alternative (limited)

If you must use bridge mode, uncomment the following and comment out `network_mode: host`:

```yaml
homeassistant:
  # network_mode: host  # ← comment out
  networks:
    - proxy
  labels:
    - traefik.enable=true
    - "traefik.http.routers.ha.rule=Host(`ha.${DOMAIN}`)"
    - traefik.http.routers.ha.entrypoints=websecure
    - traefik.http.routers.ha.tls=true
    - traefik.http.routers.ha.tls.certresolver=letsencrypt
    - traefik.http.services.ha.loadbalancer.server.port=8123
```

**Limitations of bridge mode:** mDNS, UPnP, Bluetooth, and local network device discovery will not work. Manual IP configuration required for all devices.

## Mosquitto Security

The MQTT broker requires authentication (`allow_anonymous false`):

```bash
# Create user
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/passwd myuser mypass

# Delete user
docker exec mosquitto mosquitto_passwd -D /mosquitto/config/passwd myuser

# Restart after changes
docker restart mosquitto
```

## Post-Deploy Setup

1. **Home Assistant** — Open `http://<host-ip>:8123` and create your account
2. **Zigbee2MQTT** — Open `https://ziggee.${DOMAIN}`, click "Permit Join", pair your devices
3. **Node-RED** — Open `https://nodered.${DOMAIN}`, install `node-red-contrib-home-assistant-websocket` palette
4. **ESPHome** — Open `https://esphome.${DOMAIN}`, adopt existing devices or create new firmware

### Connect Node-RED to Home Assistant

1. In Node-RED, install palette: `node-red-contrib-home-assistant-websocket`
2. Add HA server config: `ws://homeassistant:8123/api/websocket` (host network) or `ws://<host-ip>:8123/api/websocket`
3. Use long-lived access token from HA: Profile → Security → Create Token

### Connect Home Assistant to Mosquitto

In HA, go to **Settings → Devices & Services → Add Integration → MQTT**:

- Broker: `<host-ip>` (since HA is on host network)
- Port: `1883`
- Username/Password: your MQTT credentials

### Zigbee2MQTT → HA Integration

In HA, go to **Settings → Devices & Services → Add Integration → MQTT** (already configured above). Zigbee2MQTT auto-discovers and creates HA entities via MQTT auto-discovery.

### Home Assistant → ntfy Notifications

Add to HA `configuration.yaml`:

```yaml
notify:
  - name: ntfy
    platform: rest
    resource: https://ntfy.${DOMAIN}/homeassistant
    method: POST
    title_param: Title
    message_param: message
```

## Configuration Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | `example.com` | Base domain for Traefik |
| `TZ` | `Asia/Shanghai` | Timezone |
| `MQTT_USER` | `mqtt_user` | Mosquitto username |
| `MQTT_PASS` | (required) | Mosquitto password |
| `ZIGBEE2MQTT_MQTT_USER` | `mqtt_user` | Z2M MQTT user |
| `ZIGBEE2MQTT_MQTT_PASS` | (required) | Z2M MQTT password |
| `ESPHOME_OTA_PASSWORD` | (optional) | ESPHome OTA password |

Generated/reviewed with: claude-opus-4-6