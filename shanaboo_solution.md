 ```diff
--- /dev/null
+++ b/stacks/home-automation/docker-compose.yml
@@ -0,0 +1,120 @@
+version: "3.8"
+
+services:
+  # =========================================
+  # Home Assistant - 智能家居中枢
+  # =========================================
+  # 使用 host 网络模式以支持 mDNS/UPnP 设备发现
+  # 这是 Home Assistant 推荐的生产环境配置
+  home-assistant:
+    image: ghcr.io/home-assistant/home-assistant:2024.9.3
+    container_name: home-assistant
+    # 生产环境：使用 host 模式以支持设备自动发现
+    network_mode: host
+    # 替代配置（bridge 模式）- 注释掉上方 network_mode 后取消注释下方配置
+    # 限制：mDNS/UPnP 设备发现将不可用，部分集成需要手动配置 IP
+    # ports:
+    #   - "8123:8123"
+    volumes:
+      - ./config/home-assistant:/config
+      - /etc/localtime:/etc/localtime:ro
+    environment:
+      - TZ=${TZ:-UTC}
+    restart: unless-stopped
+    healthcheck:
+      test: ["CMD", "curl", "-f", "http://localhost:8123"]
+      interval: 30s
+      timeout: 10s
+      retries: 3
+      start_period: 40s
+
+  # =========================================
+  # Node-RED - 可视化流程编排
+  # =========================================
+  node-red:
+    image: nodered/node-red:4.0.3
+    container_name: node-red
+    ports:
+      - "1880:1880"
+    volumes:
+      - ./config/node-red:/data
+    environment:
+      - TZ=${TZ:-UTC}
+    restart: unless-stopped
+
+  # =========================================
+  # Mosquitto - MQTT Broker
+  # =========================================
+  mosquitto:
+    image: eclipse-mosquitto:2.0.19
+    container_name: mosquitto
+    ports:
+      - "1883:1883"
+      - "9001:9001"
+    volumes:
+      - ./config/mosquitto/mosquitto.conf:/mosquitto/config/mosquitto.conf:ro
+      - ./config/mosquitto/passwd:/mosquitto/config/passwd:ro
+      - mosquitto-data:/mosquitto/data
+      - mosquitto-logs:/mosquitto/log
+    environment:
+      - TZ=${TZ:-UTC}
+    restart: unless-stopped
+
+  # =========================================
+  # Zigbee2MQTT - Zigbee 设备网关
+  # =========================================
+  zigbee2mqtt:
+    image: koenkk/zigbee2mqtt:1.40.2
+    container_name: zigbee2mqtt
+    ports:
+      - "8080:8080"
+    volumes:
+      - ./config/zigbee2mqtt:/app/data
+      - /run/udev:/run/udev:ro
+    environment:
+      - TZ=${TZ:-UTC}
+    devices:
+      # 根据实际 Zigbee 协调器修改，常见值：
+      # - /dev/ttyACM0  (CC2531, ConBee, etc.)
+      # - /dev/ttyUSB0  (Sonoff ZBDongle, etc.)
+      - ${ZIGBEE_DEVICE:-/dev/ttyACM0}:/dev/ttyACM0
+    restart: unless-stopped
+
+  # =========================================
+  # ESPHome - ESP 设备固件管理
+  # =========================================
+  esphome:
+    image: ghcr.io/esphome/esphome:2024.9.3
+    container_name: esphome
+    ports:
+      - "6052:6052"
+    volumes:
+      - ./config/esphome:/config
+      - /etc/localtime:/etc/localtime:ro
+    environment:
+      - TZ=${TZ:-UTC}
+      - ESPHOME_DASHBOARD_USE_PING=true
+    restart: unless-stopped
+
+volumes:
+  mosquitto-data:
+  mosquitto-logs:
+
--- /dev/null
+++ b/stacks/home-automation/config/mosquitto/mosquitto.conf
@@ -0,0 +1,32 @@
+# =========================================
+# Mosquitto MQTT Broker 配置
+# =========================================
+
+# 监听端口
+listener 1883
+listener 9001
+
+# 持久化配置
+persistence true
+persistence_location /mosquitto/data/
+
+# 日志配置
+log_dest file /mosquitto/log/mosquitto.log
+log_dest stdout
+
+# 安全认证 - 启用密码文件认证
+allow_anonymous false
+password_file /mosquitto/config/passwd
+
+# 性能优化
+max_connections 100
+max_inflight_messages 20
+max_queued_messages 100
+
+# 消息保留
+retained_persistence true
+
+# 连接限制
+message_size_limit 268435455
+
+# 默认 QoS
+max_qos 2
+
--- /dev/null
+++ b/stacks/home-automation/config/mosquitto/passwd
@@ -0,0 +1,1 @@
+admin:$7$101$8K8nzV0ZWxWZ9gZY$J1PkaAOSpFLrC2D2pW2zXxWz8z8z8z8z8z8