# Home Automation Stack — Home Assistant + Node-RED + Mosquitto + Zigbee2MQTT + ESPHome

## Why `network_mode: host` for Home Assistant?

Home Assistant uses `network_mode: host` so multicast/broadcast protocols (**mDNS / Zeroconf**, **SSDP / UPnP**, **Apple HomeKit Bridge**, and **Matter/Thread**) can discover LAN IoT devices directly without Docker NAT dropping multicast packets. A commented `bridge` mode configuration is included in `docker-compose.yml` for environments that do not require L2 LAN discovery.
