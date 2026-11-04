# Home Automation Stack

Comprehensive smart home automation infrastructure incorporating Home Assistant, Node-RED, Mosquitto MQTT broker, Zigbee2MQTT, and ESPHome.

## Services Overview

| Service | Version | Access URL / Port | Purpose |
|---|---|---|---|
| **Home Assistant** | `2024.9.3` | `http://<HOST_IP>:8123` | Core smart home controller and device integrations |
| **Node-RED** | `4.0.3` | `https://nodered.${DOMAIN}` | Visual flow-based automation and logic orchestrator |
| **Mosquitto** | `2.0.19` | Ports 1883 (TCP), 9001 (WS) | MQTT messaging bus with authentication |
| **Zigbee2MQTT** | `1.40.2` | `https://zigbee.${DOMAIN}` | Zigbee to MQTT coordinator bridge |
| **ESPHome** | `2024.9.3` | `https://esphome.${DOMAIN}` | Firmware compilation & OTA management for ESP32/ESP8266 |

## Networking Architecture: Why Host Mode for Home Assistant?

Home Assistant requires `network_mode: host` to enable local network multicast (mDNS), SSDP, and HomeKit autodiscovery. In standard Docker bridge networks, multicast UDP discovery packets are not forwarded between the host subnet and Docker network, preventing Home Assistant from discovering Philips Hue, Apple TV, Chromecast, Sonos, and local smart TVs.

If `network_mode: host` cannot be used (e.g. strict firewall rules), an alternative bridge mode template is included in `docker-compose.yml` with port 8123 and Traefik routing mapped directly.

## Mosquitto Authentication Setup

```bash
# Generate password file with user/pass
docker run --rm -v $(pwd)/config/mosquitto:/mosquitto/config eclipse-mosquitto:2.0.19 mosquitto_passwd -b -c /mosquitto/config/password_file ${MQTT_USER} ${MQTT_PASSWORD}
```

## Quick Start

```bash
cp stacks/home-automation/.env.example stacks/home-automation/.env
docker compose -f stacks/home-automation/docker-compose.yml up -d
```
