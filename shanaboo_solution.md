 ```diff
--- /dev/null
+++ b/stacks/home-automation/docker-compose.yml
@@ -0,0 +1,163 @@
+version: "3.8"
+
+services:
+  # ============================================
+  # Home Assistant - 智能家居中枢
+  # ============================================
+  # 使用 host 网络模式以支持 mDNS/UPnP 设备自动发现
+  # 若使用 bridge 模式，设备发现功能将受限，需手动配置设备 IP
+  home-assistant:
+    image: ghcr.io/home-assistant/home-assistant:2024.9.3
+    container_name: home-assistant
+    # 启用 host 网络模式，支持 mDNS/UPnP 设备发现
+    network_mode: host
+    # 替代方案：bridge 模式（设备发现功能受限）
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
+    # 若使用 bridge 模式，需添加以下 healthcheck
+    # healthcheck:
+    #   test: ["CMD", "curl", "-f", "http://localhost:8123"]
+    #   interval: 30s
+    #   timeout: 10s
+    #   retries: 3
+
+  # ============================================
+  # Node-RED - 可视化流程编排
+  # ============================================
+  node-red:
+    image: nodered/node-red:4.0.3
+    container_name: node-red
+    networks:
+      - home-automation
+    ports:
+      - "1880:1880"
+    volumes:
+      - ./config/node-red:/data
+      - /etc/localtime:/etc/localtime:ro
+    environment:
+      - TZ=${TZ:-UTC}
+    restart: unless-stopped
+    healthcheck:
+      test: ["CMD", "curl", "-f", "http://localhost:1880"]
+      interval: 30s
+      timeout: 10s
+      retries: 3
+
+  # ============================================
+  # Mosquitto - MQTT Broker
+  # ============================================
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
+      - /etc/localtime:/etc/localtime:ro
+    environment:
+      - TZ=${TZ:-UTC}
+    restart: unless-stopped
+    healthcheck:
+      test: ["CMD", "mosquitto_pub", "-t", "healthcheck", "-m", "test", "-r", "-q", "1"]
+      interval: 30s
+      timeout: 10s
+      retries: 3
+
+  # ============================================
+  # Zigbee2MQTT - Zigbee 设备网关
+  # ============================================
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
+      - /etc/localtime:/etc/localtime:ro
+    environment:
+      - TZ=${TZ:-UTC}
+    devices:
+      # 根据实际 Zigbee 适配器修改设备路径
+      # 常见适配器：/dev/ttyUSB0, /dev/ttyACM0, /dev/ttyAMA0
+      - ${ZIGBEE_DEVICE:-/dev/ttyUSB0}:/dev/ttyUSB0
+    restart: unless-stopped
+    depends_on:
+      - mosquitto
+
+  # ============================================
+  # ESPHome - ESP 设备固件管理
+  # ============================================
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
+    healthcheck:
+      test: ["CMD", "curl", "-f", "http://localhost:6052"]
+      interval: 30s
+      timeout: 10s
+      retries: 3
+
+networks:
+  home-automation:
+    name: home-automation
+
+volumes:
+  mosquitto-data:
+    name: mosquitto-data
+  mosquitto-logs:
+    name: mosquitto-logs
+
--- /dev/null
+++ b/stacks/home-automation/.env.example
@@ -0,0 +1,12 @@
+# ============================================
+# Home Automation Stack Environment Variables
+# ============================================
+
+# 时区设置
+TZ=Asia/Shanghai
+
+# Zigbee 适配器设备路径
+# 根据实际硬件修改：/dev/ttyUSB0, /dev/ttyACM0, /dev/ttyAMA0 等
+ZIGBEE_DEVICE=/dev/ttyUSB0
+
+# ============================================
--- /dev/null
+++ b/stacks/home-automation/config/mosquitto/mosquitto.conf
@@ -0,0 +1,42 @@
+# ============================================
+# Mosquitto MQTT Broker 安全配置
+# ============================================
+
+# 监听端口
+listener 1883
+listener 9001
+
+# 持久化设置
+persistence true
+persistence_location /mosquitto/data/
+
+# 日志配置
+log_dest file /mosquitto/log/mosquitto.log
+log_dest stdout
+log_type all
+
+# 允许匿名访问（内网环境，如需公网访问建议启用认证）
+allow_anonymous true
+
+# 认证配置（可选，取消注释启用密码认证）
+# password_file /mosquit