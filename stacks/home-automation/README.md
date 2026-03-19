# 🏠 Home Automation Stack

> Smart home control, Zigbee integration, and automation flows.

**Services:** Home Assistant · Node-RED · Mosquitto · Zigbee2MQTT  
**Bounty:** $130 USDT ([#7](https://github.com/illbnm/homelab-stack/issues/7))

---

## 🏗️ Architecture

```
Zigbee Devices (sensors, switches, bulbs)
       │
       └──► Zigbee2MQTT  ──► Mosquitto (MQTT broker)
                                     │
                                     ├──► Home Assistant  (main UI & automation engine)
                                     │         https://ha.${DOMAIN}
                                     │
                                     └──► Node-RED        (visual flow automation)
                                              https://nodered.${DOMAIN}

Local Network: MQTT on port 1883 (exposed to host)
```

**Mosquitto** is the central MQTT message broker. All devices and services communicate through it.
**Zigbee2MQTT** bridges Zigbee devices to MQTT.
**Home Assistant** is the main smart home platform.
**Node-RED** provides visual automation flows for power users.

---

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Base infrastructure must be running first
docker network create proxy 2>/dev/null || true

# Zigbee2MQTT needs a Zigbee USB dongle (e.g. CC2652, SONOFF ZBDongle-E)
# Plug it into the host and find its device path:
ls /dev/serial/by-id/
# e.g. /dev/serial/by-id/usb-Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_...
```

### 2. Configure environment

```bash
cd stacks/home-automation
cp .env.example .env
nano .env
```

Required `.env` variables:

```env
DOMAIN=yourdomain.com
TZ=Asia/Shanghai
# Serial device for your Zigbee dongle (find with: ls /dev/serial/by-id/)
ZIGBEE_SERIAL_DEVICE=/dev/serial/by-id/usb-Silicon_Labs_...
```

### 3. Configure Zigbee2MQTT

Edit the Zigbee2MQTT data directory configuration:

```bash
# Create Zigbee2MQTT configuration
mkdir -p data/zigbee2mqtt
cat > data/zigbee2mqtt/configuration.yaml << 'EOF'
homeassistant: true
permit_join: false
mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://mosquitto:1883
serial:
  port: /dev/serial/by-id/usb-Silicon_Labs_...  # your device path
frontend:
  port: 8080
EOF
```

### 4. Start services

```bash
docker compose up -d
```

### 5. Access services

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Home Assistant | `https://ha.${DOMAIN}` | First user (web setup) |
| Node-RED | `https://nodered.${DOMAIN}` | No auth by default |
| Zigbee2MQTT | `https://zigbee.${DOMAIN}` | No auth |
| Mosquitto | `mqtt://host:1883` | No auth |

---

## 🌐 Service URLs (after DNS + Traefik)

| Service | URL | Notes |
|---------|-----|-------|
| Home Assistant | `https://ha.${DOMAIN}` | Main smart home UI |
| Node-RED | `https://nodered.${DOMAIN}` | Visual automation editor |
| Zigbee2MQTT | `https://zigbee.${DOMAIN}` | Zigbee device management |
| Mosquitto | Port `1883` on host | MQTT broker (local network only) |

---

## 🔌 Adding Devices

### Permit Zigbee joins

```bash
# Temporary: enable join for 60 seconds
docker exec -it zigbee2mqtt npm start

# Or permanently enable/disable in Zigbee2MQTT UI:
# https://zigbee.${DOMAIN} → Permit join (toggle)
```

### Common device pairings

| Device Type | Typical Pairing Method |
|-------------|----------------------|
| Xiaomi/Aqara | Hold reset button 5s until LED blinks |
| Philips Hue | Power cycle 3x |
| IKEA TRÅDFRI | Hold reset button 4s |
| Generic | Check device manual |

### Verify device in Home Assistant

1. Go to `https://ha.${DOMAIN}`
2. Settings → Devices & Services → Devices
3. Your Zigbee device should appear automatically (via MQTT auto-discovery)

---

## 🔧 Common Tasks

### Create a Home Assistant automation (UI)

1. `https://ha.${DOMAIN}` → Settings → Automations → Create Automation
2. Example: turn on light when motion detected
   - Trigger: State of motion sensor = `on`
   - Action: Call service `light.turn_on` on target light entity

### Create a Node-RED flow

1. `https://nodered.${DOMAIN}`
2. Drag an **mqtt in** node → configure to subscribe to `zigbee2mqtt/+/motion`
3. Drag a **change** node → set `msg.payload = "on"`
4. Drag an **http request** node → call Home Assistant API
5. Deploy

### Check MQTT messages

```bash
# Subscribe to all Zigbee2MQTT messages
docker exec -it mosquitto mosquitto_sub -t 'zigbee2mqtt/#' -v

# Publish a test message
docker exec -it mosquitto mosquitto_pub -t 'zigbee2mqtt/my-device/set' -m '{"state": "ON"}'
```

### View Zigbee2MQTT logs

```bash
docker compose logs -f zigbee2mqtt
```

---

## 🏳️ SSO / Authentik Integration

Home Assistant does not support OIDC natively in the core version (requires Home Assistant Cloud or add-on). To protect it via Traefik ForwardAuth:

1. Set up [Authentik SSO Stack](../sso/) first
2. Add to Home Assistant docker-compose labels:
   ```yaml
   labels:
     - "traefik.http.middlewares.ha-auth.forwardauth.address=https://${AUTHENTIK_DOMAIN}/outpost.goauthentik.io/auth/traefik"
     - "traefik.http.middlewares.ha-auth.forwardauth.trustForwardHeader=true"
     - "traefik.http.routers.ha.middlewares=ha-auth"
   ```

Node-RED: add HTTP Basic Auth or use the `@node-red/node-red-admin` auth module.

---

## 🐛 Troubleshooting

### Zigbee devices not pairing

1. Check Zigbee2MQTT logs: `docker compose logs zigbee2mqtt | tail -50`
2. Make sure `permit_join: true` is set temporarily
3. Check the device is in pairing mode (LED indicator)
4. Move the Zigbee dongle closer to the device (Zigbee range issues)
5. Check if device is already paired (reset first)

### Home Assistant not discovering MQTT devices

1. Verify Mosquitto is running: `docker compose logs mosquitto`
2. Check MQTT in Home Assistant:
   - Settings → Devices & Services → Add Integration → MQTT
   - Broker: `mosquitto`, Port: `1883`
3. Verify `homeassistant: true` is in Zigbee2MQTT `configuration.yaml`

### Node-RED can't connect to MQTT

1. MQTT broker address must be the **container name**, not `localhost`:
   - Correct: `mqtt://mosquitto:1883`
   - Wrong: `mqtt://localhost:1883`

### Mosquitto container keeps restarting

```bash
# Check logs
docker compose logs mosquitto

# Verify mosquitto.conf is valid
docker exec -it mosquitto mosquitto -c /mosquitto/config/mosquitto.conf -v
```

---

## 📁 File Structure

```
stacks/home-automation/
├── docker-compose.yml
├── mosquitto.conf        ← MQTT broker config
├── data/
│   └── zigbee2mqtt/
│       └── configuration.yaml
└── .env

Docker volumes:
  ha-config         → /config (Home Assistant data)
  node-red-data     → /data (flows, credentials)
  mosquitto-data    → /mosquitto/data
  mosquitto-logs    → /mosquitto/log
  zigbee2mqtt-data  → /app/data (database, configuration)
```

---

## 🔄 Update services

```bash
cd stacks/home-automation
docker compose pull
docker compose up -d
```

---

## 🗑️ Tear down

```bash
cd stacks/home-automation
docker compose down        # keeps volumes
docker compose down -v    # removes volumes (loses all device pairings and history!)
```

---

## 📋 Acceptance Criteria

- [x] Home Assistant starts and is accessible via Traefik
- [x] Node-RED starts and is accessible via Traefik
- [x] Mosquitto MQTT broker runs with health check
- [x] Zigbee2MQTT bridges Zigbee to MQTT
- [x] Image tags are pinned versions
- [x] README documents full setup, device pairing, and MQTT integration
