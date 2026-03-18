# 🏠 Home Automation Stack — Home Assistant + Node-RED + Zigbee2MQTT

> 完整智能家居自动化栈：中枢控制、可视化编排、MQTT 通信、Zigbee/ESP 设备接入。

## 服务清单

| 服务 | 镜像 | URL/端口 | 用途 |
|------|------|---------|------|
| **Home Assistant** | `home-assistant:2024.9.3` | `:8123` (host) | 智能家居中枢 |
| **Node-RED** | `nodered/node-red:4.0.3` | `nodered.${DOMAIN}` | 可视化流程编排 |
| **Mosquitto** | `eclipse-mosquitto:2.0.19` | `:1883` | MQTT Broker |
| **Zigbee2MQTT** | `koenkk/zigbee2mqtt:1.40.2` | `zigbee.${DOMAIN}` | Zigbee 设备网关 |
| **ESPHome** | `esphome:2024.9.3` | `esphome.${DOMAIN}` | ESP 设备固件管理 |

## 快速启动

```bash
# 1. 配置 .env
MQTT_USER=homeassistant
MQTT_PASSWORD=your_mqtt_password
ZIGBEE_DEVICE=/dev/ttyUSB0    # Zigbee 适配器设备路径

# 2. 生成 Mosquitto 密码
docker run --rm eclipse-mosquitto:2.0.19 \
  mosquitto_passwd -b /dev/stdout homeassistant your_mqtt_password \
  > config/mosquitto/password_file

# 3. 启动
docker compose -f stacks/home-automation/docker-compose.yml up -d
```

## Home Assistant 网络模式

### 为什么使用 host 网络？

Home Assistant 使用 `network_mode: host` 是因为：
- **mDNS 发现**: Chromecast, Google Home, Sonos 等设备通过 mDNS 广播
- **UPnP/SSDP**: 许多 IoT 设备使用 UPnP 进行发现
- **蓝牙**: 直接访问主机蓝牙适配器
- **低延迟**: 避免 Docker NAT 带来的延迟

### Bridge 模式替代

如果不需要设备发现，可以切换到 bridge 模式（docker-compose.yml 中有注释配置）。

Bridge 模式限制：
- ❌ 无 mDNS 设备发现
- ❌ 无 UPnP/SSDP
- ❌ 无蓝牙
- ✅ 可通过 Traefik 反代

## Mosquitto MQTT

### 配置
- 认证: 用户名/密码 (禁用匿名)
- 持久化: 启用
- 端口: 1883 (TCP)

### 添加用户
```bash
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/password_file <username> <password>
docker restart mosquitto
```

### 测试连接
```bash
# 订阅
mosquitto_sub -h localhost -t "test/#" -u homeassistant -P your_password

# 发布
mosquitto_pub -h localhost -t "test/hello" -m "world" -u homeassistant -P your_password
```

## Zigbee2MQTT

### 前置要求
- Zigbee USB 适配器 (推荐: SONOFF Zigbee 3.0 USB Dongle Plus)
- 确认设备路径: `ls /dev/ttyUSB*` 或 `ls /dev/ttyACM*`

### 首次配置
Zigbee2MQTT 首次启动会生成 `configuration.yaml`，需要配置：
```yaml
mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://mosquitto:1883
  user: homeassistant
  password: your_mqtt_password
serial:
  port: /dev/ttyACM0
frontend:
  port: 8080
```

### Home Assistant 集成
1. Home Assistant → Settings → Devices & Services
2. Add Integration → MQTT
3. Broker: `localhost` (host 网络) 或 `mosquitto` (bridge 网络)
4. Port: `1883`
5. Username/Password: MQTT 凭证

## Node-RED

### Home Assistant 集成
1. 安装 `node-red-contrib-home-assistant-websocket`
2. 配置 Home Assistant 节点:
   - URL: `http://localhost:8123` (host 网络)
   - Access Token: 从 HA → Profile → Long-Lived Access Tokens 生成

## ESPHome

访问 `https://esphome.${DOMAIN}` 管理 ESP8266/ESP32 设备固件。
