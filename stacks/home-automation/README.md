# 🏠 Home Automation Stack (Home Assistant + Node-RED + Mosquitto + Zigbee2MQTT + ESPHome)

This stack provides smart home orchestration, MQTT messaging, Zigbee device integration, and visual flow automation.

---

## 📦 Services Included

- **Home Assistant (`2024.9.3`)**: Central smart home hub (`network_mode: host`).
- **Node-RED (`4.0.3`)**: Flow-based programming for IoT devices.
- **Mosquitto (`2.0.19`)**: Secured MQTT broker.
- **Zigbee2MQTT (`1.40.2`)**: Zigbee to MQTT bridge.
- **ESPHome (`2024.9.3`)**: ESP8266/ESP32 firmware manager.

---

## 🌐 Host Network Mode vs Bridge Mode

### Why Host Mode is Required for Home Assistant
Home Assistant uses **mDNS** (Multicast DNS), SSDP, and UPnP protocols to automatically discover smart TVs, Apple TVs, Google Cast, and Matter/Thread devices on local LAN subnets. Running under Docker `bridge` mode blocks mDNS broadcasts.

### Bridge Mode Alternative
If running behind Traefik reverse proxy under `bridge` mode, comment `network_mode: host` in `docker-compose.yml` and enable `networks: [proxy]` and Traefik labels. Note that automatic local device discovery will be limited.

---

## 🔐 Mosquitto MQTT Authentication

Mosquitto configuration (`config/mosquitto/mosquitto.conf`) disables anonymous access. Generate password file:

```bash
docker exec -it mosquitto mosquitto_passwd -c /mosquitto/config/password_file zigbee2mqtt
```
