# Home Automation Stack

Services for smart home automation: Home Assistant, Node-RED, Mosquitto (MQTT), Zigbee2MQTT, and ESPHome.

## Quick Start

```bash
cd stacks/home-automation

# 1. Copy and fill .env (or use root .env)
cp ../../.env.example ../../.env  # edit as needed

# 2. Create MQTT users
docker compose up -d mosquitto
docker exec mosquitto mosquitto_passwd -c /mosquitto/config/auth/passwd homeassistant
docker exec mosquitto mosquitto_passwd   /mosquitto/config/auth/passwd zigbee2mqtt
docker exec mosquitto mosquitto_passwd   /mosquitto/config/auth/passwd nodered
docker compose restart mosquitto

# 3. Copy HA config and start everything
docker compose up -d
```

## Services

| Service | URL | Description |
|---------|-----|-------------|
| Home Assistant | `http://<host>:8123` | Home automation hub |
| Node-RED | `https://nodered.<domain>` | Flow-based automation |
| Zigbee2MQTT | `https://zigbee.<domain>` | Zigbee device management |
| ESPHome | `https://esphome.<domain>` | ESP device firmware |

## network_mode: host — Why?

Home Assistant runs in **host network mode** by default because:

- **mDNS/SSDP discovery** — HA uses multicast to auto-discover devices (Chromecast, Hue, etc.). Bridge networking breaks multicast.
- **USB passthrough** — Zigbee/Bluetooth dongles are accessed directly at `/dev/ttyUSBx`.
- **Fewer port conflicts** — HA binds directly to host ports (8123, 5353, etc.).

### Switching to Bridge Mode

If host mode causes conflicts (e.g., port 8123 already in use), uncomment the **"Bridge mode alternative"** block in `docker-compose.yml` for Home Assistant. You will lose automatic mDNS discovery — add devices manually or use integrations that support explicit IPs.

> ⚠️ **Important:** With bridge mode, Traefik labels become available for HA. With host mode, HA is accessed directly on port 8123 (or via a reverse proxy in front of the host).

## Zigbee Adapter Setup

### 1. Find Your Dongle

```bash
ls -la /dev/serial/by-id/
```

Common devices:

| Adapter | USB Path Pattern |
|---------|-----------------|
| Sonoff Zigbee 3.0 Dongle Plus | `usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_*` |
| ConBee II | `usb-dresden_elektronik_ingenieurtechnik_GmbH_ConBee_II_*` |
| SkyConnect | `usb-Nabu_Casa_SkyConnect_*` |

### 2. Configure

Set `ZIGBEE_ADAPTER` in `.env`:

```env
ZIGBEE_ADAPTER=/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0
```

### 3. Permissions

Add the Docker user to the `dialout` group:

```bash
sudo usermod -aG dialout $USER
# Re-login required
```

## Adding Devices

### Zigbee Devices

1. Open Zigbee2MQTT dashboard at `https://zigbee.<domain>`
2. Go to **Settings → Zigbee** → verify adapter is connected
3. Click **"Add device"** (or toggle permit join)
4. Put your Zigbee device into pairing mode (usually hold button 5s)
5. Device appears in Zigbee2MQTT → auto-discovered in Home Assistant via MQTT

### ESP Devices

1. Flash ESPHome firmware via `https://esphome.<domain>`
2. Connect new device → enter WiFi credentials
3. Add integration in Home Assistant: **Settings → Devices & Services → ESPHome**
4. Devices auto-discover

### MQTT Devices

1. Configure in Node-RED or directly in Home Assistant
2. Use broker `mosquitto` on port `1883` with your credentials

## Mosquitto Security

- **Authentication:** Password-protected (see Quick Start step 2)
- **ACL:** `auth/acl` defines per-user topic permissions
- **Users:** `homeassistant`, `zigbee2mqtt`, `nodered` (create via `mosquitto_passwd`)

## Volumes

| Volume | Contents |
|--------|----------|
| `ha-config` | Home Assistant configuration & data |
| `node-red-data` | Node-RED flows & credentials |
| `mosquitto-data` | MQTT persistence |
| `zigbee2mqtt-data` | Zigbee network & device database |
| `esphome-data` | ESP device configurations |
