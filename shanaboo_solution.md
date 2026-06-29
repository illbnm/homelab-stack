 ```diff
--- a/README.md
+++ b/README.md
@@ -1,4 +1,4 @@
-# 🏠 HomeLab Stack
+🏠 HomeLab Stack
 
 > One-click self-hosted services deployment platform for home servers and VPS.
 
@@ -6,7 +6,6 @@
 [![Bounties](https://img.shields.io/badge/bounties-%242340-orange)](BOUNTY.md)
 [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
 [![Docker](https://img.shields.io/badge/docker-required-blue.svg)](https://docs.docker.com/get-docker/)
-[![Self Hosted](https://img.shields.io/badge/self--hosted-40%2B%20services-purple.svg)](BOUNTY.md)
 [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
 [![Bounties Available](https://img.shields.io/badge/bounties-available-orange.svg)](BOUNTY.md)
 
@@ -33,7 +32,7 @@ docker compose -f docker-compose.base.yml up -d
 | [Network](stacks/network/) | AdGuard Home, WireGuard Easy, Cloudflare DDNS, Nginx Proxy Manager | [#5](../../issues/5) |
 | [Productivity](stacks/productivity/) | Gitea, Vaultwarden, Outline, Stirling-PDF, IT-Tools | [#6](../../issues/6) |
 | [AI](stacks/ai/) | Ollama, Open WebUI, LocalAI, n8n | [#7](../../issues/7) |
-| [Home Automation](stacks/home-automation/) | Home Assistant, Node-RED, Mosquitto, Zigbee2MQTT, ESPHome | [#8](../../issues/8) |
+| [Home Automation](stacks/home-automation/) | Home Assistant, Node-RED, Mosquitto, Zigbee2MQTT, ESPHome | ✅ Bounty |
 | [SSO / Auth](stacks/sso/) | Authentik, PostgreSQL, Redis | [#9](../../issues/9) |
 | [Dashboard](stacks/dashboard/) | Homepage, Heimdall | [#10](../../issues/10) |
 | [Notifications](stacks/notifications/) | Gotify, Ntfy, Apprise | [#11](../../issues/11) |
@@ -51,3 +50,4 @@ Internet
    ├── [Media Stack]   ← Jellyfin + *arr suite
    ├── [Storage]       ← Nextcloud + MinIO
    └── ...
+
--- a/stacks/home-automation/docker-compose.yml
+++ b/stacks/home-automation/docker-compose.yml
@@ -0,0 +1,120 @@
+services:
+  # Home Assistant - 智能家居中枢
+  # 使用 host 网络模式以支持 mDNS/UPnP 设备发现
+  home-assistant:
+    image: ghcr.io/home-assistant/home-assistant:2024.9.3
+    container_name: home-assistant
+    # host 模式：支持 mDNS/UPnP 设备自动发现，无需端口映射
+    network_mode: host
+    # 替代方案：bridge 模式（功能受限，部分设备无法自动发现）
+    # networks:
+    #   - home-automation
+    # ports:
+    #   - "8123:8123"
+    volumes:
+      - ./config/home-assistant:/config
+      - /etc/localtime:/etc/localtime:ro
+    environment:
+      - TZ=${TZ:-UTC}
+    restart: unless-stopped
+    # 如果使用 bridge 模式，取消注释以下 healthcheck
+    # healthcheck:
+    #   test: ["CMD", "curl", "-f", "http://localhost:8123"]
+    #   interval: 30s
+    #   timeout: 10s
+    #   retries: 3
+
+  # Node-RED - 可视化流程编排
+  node-red:
+    image: nodered/node-red:4.0.3
+    container_name: node-red
+    networks:
+      - home-automation
+    ports:
+      - "1880:1880"
+    volumes:
+      - ./config/node-red:/data
+    environment:
+      - TZ=${TZ:-UTC}
+    restart: unless-stopped
+
+  # Mosquitto - MQTT Broker
+  mosquitto:
+    image: eclipse-mosquitto:2.0.19
+    container_name: mosquitto
+    networks:
+      - home-automation
+    ports:
+      - "1883:1883"
+      - "9001:9001"
+    volumes:
+      - ./config/mosquitto:/mosquitto/config
+      - mosquitto-data:/mosquitto/data
+      - mosquitto-logs:/mosquitto/log
+    environment:
+      - TZ=${TZ:-UTC}
+    restart: unless-stopped
+
+  # Zigbee2MQTT - Zigbee 设备网关
+  zigbee2mqtt:
+    image: koenkk/zigbee2mqtt:1.40.2
+    container_name: zigbee2mqtt
+    networks:
+      - home-automation
+    ports:
+      - "8080:8080"
+    volumes:
+      - ./config/zigbee2mqtt:/app/data
+      - /run/udev:/run/udev:ro
+    environment:
+      - TZ=${TZ:-UTC}
+    devices:
+      # 根据实际 Zigbee 适配器修改，例如：
+      # - /dev/ttyACM0:/dev/ttyACM0
+      # - /dev/ttyUSB0:/dev/ttyUSB0
+      - ${ZIGBEE_DEVICE:-/dev/null}:/dev/zigbee
+    restart: unless-stopped
+
+  # ESPHome - ESP 设备固件管理
+  esphome:
+    image: ghcr.io/esphome/esphome:2024.9.3
+    container_name: esphome
+    networks:
+      - home-automation
+    ports:
+      - "6052:6052"
+    volumes:
+      - ./config/esphome:/config
+      - /etc/localtime:/etc/localtime:ro
+    environment:
+      - TZ=${TZ:-UTC}
+    restart: unless-stopped
+
+networks:
+  home-automation:
+    driver: bridge
+
+volumes:
+  mosquitto-data:
+  mosquitto-logs:
--- a/stacks/home-automation/README.md
+++ b/stacks/home-automation/README.md
@@ -0,0 +1,72 @@
+# 🏠 Home Automation Stack
+
+完整的智能家居自动化栈，支持 Zigbee 