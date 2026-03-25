# Home Automation Stack

Complete smart home automation stack with Zigbee support and visual programming.

## Services

| Service | Image | Ports | Purpose |
|---------|-------|-------|---------|
| Home Assistant | `ghcr.io/home-assistant/home-assistant:2024.9.3` | 8123 | Smart home hub |
| Node-RED | `nodered/node-red:4.0.3` | 1880 | Visual programming |
| Mosquitto | `eclipse-mosquitto:2.0.19` | 1883, 9001 | MQTT broker |
| Zigbee2MQTT | `koenkk/zigbee2mqtt:1.40.2` | 8080 | Zigbee gateway |
| ESPHome | `ghcr.io/esphome/esphome:2024.9.3` | 6052 | ESP firmware |

## Quick Start

### 1. Configure Environment

```bash
cp .env.example .env
nano .env
```

### 2. Set Up Zigbee Device

```bash
# Check available devices
ls -la /dev/ttyUSB* /dev/ttyACM*

# Update ZIGBEE_DEVICE in .env
ZIGBEE_DEVICE=/dev/ttyUSB0

# Add user to dialout group (for USB access)
sudo usermod -aG dialout $USER
```

### 3. Start Services

```bash
docker compose up -d
```

### 4. Access Services

| Service | URL | Notes |
|---------|-----|-------|
| Home Assistant | http://your-server:8123 | host network, no HTTPS |
| Node-RED | https://nodered.yourdomain.com | Traefik HTTPS |
| Zigbee2MQTT | https://zigbee.yourdomain.com | Traefik HTTPS |
| ESPHome | https://esphome.yourdomain.com | Traefik HTTPS |

## Important: Home Assistant Network Mode

**Home Assistant uses `network_mode: host`** for device discovery:

- ✅ mDNS discovery (Google Cast, Apple TV, Chromecast)
- ✅ UPnP discovery
- ✅ Local device communication
- ❌ No Traefik HTTPS (access directly via http://IP:8123)

If you need Traefik HTTPS, uncomment the bridge mode configuration in `docker-compose.yml`, but be aware:
- mDNS discovery will NOT work
- You'll need to manually configure devices

## Configuration

### Home Assistant

#### First Setup

1. Access http://your-server:8123
2. Create admin account
3. Configure integrations

#### MQTT Integration

1. Settings → Devices → Add Integration → MQTT
2. Broker: `mosquitto` (or IP address if host network)
3. Port: `1883`

#### Zigbee2MQTT Integration

1. Settings → Devices → Add Integration → MQTT
2. Base topic: `zigbee2mqtt`

### Node-RED

#### First Setup

1. Access https://nodered.yourdomain.com
2. No authentication by default (add via Node-RED settings)

#### Home Assistant Integration

1. Manage Palette → Install `node-red-contrib-home-assistant-websocket`
2. Configure WebSocket connection:
   - Server: `ws://homeassistant:8123` (or IP if host network)
   - Access Token: Generate in Home Assistant

### Mosquitto

#### Set Up Authentication (Recommended)

```bash
# Create password file
docker exec -it mosquitto mosquitto_passwd -c /mosquitto/config/passwd mqtt_user

# Update config/mosquitto/mosquitto.conf:
# allow_anonymous false
# password_file /mosquitto/config/passwd

# Restart
docker compose restart mosquitto
```

#### Test MQTT

```bash
# Subscribe
docker exec -it mosquitto mosquitto_sub -h localhost -t test/topic

# Publish (in another terminal)
docker exec -it mosquitto mosquitto_pub -h localhost -t test/topic -m "Hello"
```

### Zigbee2MQTT

#### Pair Devices

1. Access https://zigbee.yourdomain.com
2. Click "Permit Join"
3. Put your Zigbee device in pairing mode
4. Device appears in dashboard

#### Network Key

For security, generate a unique network key:

```bash
dd if=/dev/urandom bs=1 count=16 2>/dev/null | xxd -p
```

Add to `config/zigbee2mqtt/configuration.yaml`:
```yaml
advanced:
  network_key: YOUR_GENERATED_KEY
```

### ESPHome

#### First Setup

1. Access https://esphome.yourdomain.com
2. Click "New Device"
3. Configure your ESP device

#### Example ESP32 Configuration

```yaml
esphome:
  name: living-room-sensor
  friendly_name: Living Room Sensor

esp32:
  board: esp32dev

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password

# Home Assistant API
api:
  encryption:
    key: !secret api_key

# OTA updates
ota:
  password: !secret ota_password

# Sensors
sensor:
  - platform: dht
    pin: GPIO4
    temperature:
      name: "Living Room Temperature"
    humidity:
      name: "Living Room Humidity"
```

## Architecture

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                   Home Assistant                        │
                    │                (host network mode)                      │
                    │                     Port 8123                           │
                    └───────────────────────────┬─────────────────────────────┘
                                                │
                    ┌───────────────────────────┼─────────────────────────────┐
                    │                           │                             │
                    ▼                           ▼                             ▼
            ┌───────────────┐          ┌───────────────┐            ┌───────────────┐
            │   Node-RED    │          │   Mosquitto   │            │  Zigbee2MQTT  │
            │  (Visual)     │◄────────►│    (MQTT)     │◄──────────►│   (Zigbee)    │
            └───────────────┘          └───────┬───────┘            └───────┬───────┘
                                               │                            │
                                               │                            ▼
                                               │                    ┌───────────────┐
                                               │                    │  Zigbee USB   │
                                               │                    │   Dongle      │
                                               │                    └───────────────┘
                                               ▼
                                        ┌───────────────┐
                                        │   ESPHome     │
                                        │  (ESP8266/    │
                                        │   ESP32)      │
                                        └───────────────┘
```

## Health Checks

```bash
# Home Assistant
curl -sf http://localhost:8123/api/

# Node-RED
curl -sf http://localhost:1880/

# Mosquitto
docker exec mosquitto mosquitto_sub -t '$SYS/#' -C 1 -W 3

# Zigbee2MQTT
curl -sf http://localhost:8080/health

# ESPHome
curl -sf http://localhost:6052/version
```

## Troubleshooting

### Zigbee Device Not Detected

```bash
# Check USB device
ls -la /dev/ttyUSB* /dev/ttyACM*

# Check permissions
sudo chmod 666 /dev/ttyUSB0

# Check logs
docker logs zigbee2mqtt
```

### Home Assistant Discovery Not Working

- Ensure `network_mode: host` is set
- Check firewall allows mDNS (port 5353/UDP)
- Devices must be on same network

### Mosquitto Authentication Failed

```bash
# Reset password file
docker exec -it mosquitto mosquitto_passwd -c /mosquitto/config/passwd new_user
docker compose restart mosquitto
```

### ESPHome OTA Update Failed

- Ensure ESP device is on same network
- Check firewall allows ESPHome port (6053)
- Verify WiFi credentials in ESPHome config

## Resource Requirements

| Service | Min Memory | Recommended |
|---------|------------|-------------|
| Home Assistant | 256 MB | 512 MB - 1 GB |
| Node-RED | 128 MB | 256 MB |
| Mosquitto | 32 MB | 64 MB |
| Zigbee2MQTT | 64 MB | 128 MB |
| ESPHome | 128 MB | 256 MB |
| **Total** | **608 MB** | **1.2 - 1.7 GB** |

## Security Notes

1. **Set Mosquitto authentication** in production
2. **Change Zigbee network key** for security
3. **Use HTTPS** for external access
4. **Segment IoT devices** on separate VLAN if possible

## License

MIT
