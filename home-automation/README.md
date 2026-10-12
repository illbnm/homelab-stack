# Home Automation Stack

This directory contains a Docker Compose setup for a comprehensive home automation stack, including:

*   **Home Assistant**: The central smart home hub.
*   **Node-RED**: For advanced visual flow-based automations.
*   **Mosquitto**: A lightweight MQTT broker for inter-service communication.
*   **Zigbee2MQTT**: A gateway to integrate Zigbee devices via MQTT.
*   **ESPHome**: For managing ESP-based devices and custom firmware.

## Services Overview

| Service          | Image                                   | Port(s) | Purpose                                    |
| :--------------- | :-------------------------------------- | :------ | :----------------------------------------- |
| `homeassistant`  | `ghcr.io/home-assistant/home-assistant` | `8123`  | Smart home central hub                     |
| `nodered`        | `nodered/node-red`                      | `1880`  | Visual automation flow editor              |
| `mosquitto`      | `eclipse-mosquitto`                     | `1883`, `9001` | MQTT Broker (standard & WebSockets)        |
| `zigbee2mqtt`    | `koenkk/zigbee2mqtt`                    | `8080`  | Zigbee device gateway via MQTT             |
| `esphome`        | `ghcr.io/esphome/esphome`               | `6052`  | ESP device firmware management             |

## Prerequisites

1.  **Docker and Docker Compose**: Ensure Docker and Docker Compose are installed on your system.
2.  **Zigbee Coordinator**: A USB Zigbee coordinator (e.g., Sonoff Zigbee 3.0 USB Dongle Plus, ConBee II) is required for Zigbee2MQTT.
    *   **Identify your Zigbee Coordinator's path**:
        *   Plug in your Zigbee coordinator.
        *   Run `ls -l /dev/serial/by-id/` to find its symbolic link (e.g., `usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_20230810140707-if00`).
        *   Alternatively, `dmesg | grep tty` might show it as `/dev/ttyUSB0` or similar.
        *   **Update `docker-compose.yml`**: Modify the `devices` section for `zigbee2mqtt` to use the correct path (e.g., `/dev/ttyUSB0` or `/dev/serial/by-id/your-coordinator-id`).
    *   **Grant permissions (if necessary)**: Your Docker user might need access to serial devices. Add your user to the `dialout` group: `sudo usermod -a -G dialout $USER`. You may need to log out and back in for changes to take effect.

## Setup Instructions

1.  **Navigate to the directory**:
    