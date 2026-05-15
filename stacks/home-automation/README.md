# Home Automation Stack

完整的智能家居自动化栈，支持 Zigbee 设备接入、可视化流程编排和 ESP 设备固件管理。

## 服务清单

| 服务 | 版本 | URL | 用途 |
|------|------|-----|------|
| Home Assistant | 2024.9.3 | `http://<host_ip>:8123` | 智能家居中枢 |
| Node-RED | 4.0.3 | `https://nodered.<DOMAIN>` | 可视化流程编排 |
| Mosquitto | 2.0.19 | `mqtt://<host_ip>:1883` | MQTT Broker |
| Zigbee2MQTT | 1.40.2 | `https://zigbee.<DOMAIN>` | Zigbee 设备网关 |
| ESPHome | 2024.9.3 | `http://<host_ip>:6052` | ESP 设备固件管理 |

## 架构图

```
┌─────────────────────────────────────────────────────────────────────┐
│                        LAN / Network                                │
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐  │
│  │ Zigbee USB   │    │ ESP Devices  │    │ Smart Home Devices   │  │
│  │ Dongle       │    │ (ESP32/8266) │    │ (mDNS/UPnP)          │  │
│  └──────┬───────┘    └──────┬───────┘    └──────────┬───────────┘  │
│         │                   │                        │              │
│         ▼                   ▼                        ▼              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐  │
│  │ Zigbee2MQTT  │    │   ESPHome    │    │   Home Assistant     │  │
│  │ :8080        │    │   :6052      │    │   :8123 (host net)   │  │
│  └──────┬───────┘    └──────┬───────┘    └──────────┬───────────┘  │
│         │                   │                        │              │
│         └───────────────────┼────────────────────────┘              │
│                             │                                       │
│                             ▼                                       │
│                    ┌─────────────────┐                              │
│                    │    Mosquitto    │                              │
│                    │  MQTT :1883     │                              │
│                    │  WS   :9001     │                              │
│                    └────────┬────────┘                              │
│                             │                                       │
│                             ▼                                       │
│                    ┌─────────────────┐                              │
│                    │    Node-RED     │                              │
│                    │   :1880         │                              │
│                    │  (Traefik)      │                              │
│                    └─────────────────┘                              │
│                                                                     │
│                    ┌─────────────────┐                              │
│                    │     Traefik     │                              │
│                    │  (Reverse Proxy)│                              │
│                    └─────────────────┘                              │
└─────────────────────────────────────────────────────────────────────┘

数据流:
  Zigbee Device ──► Zigbee2MQTT ──► MQTT ──► Home Assistant
  ESP Device ──────► ESPHome ──────► MQTT ──► Home Assistant
  MQTT ────────────► Node-RED ─────► Automations ──► Devices
```

## 网络模式说明

### Home Assistant — 为什么使用 host 网络模式？

Home Assistant 使用 `network_mode: host` 是为了支持以下功能：

1. **mDNS 设备发现** — 自动发现同一局域网内的智能家居设备（如 Chromecast、Sonos）
2. **UPnP/SSDP** — 发现 UPnP 兼容设备
3. **DHCP 服务器集成** — 用于设备追踪
4. **ESPHome OTA 更新** — 通过网络更新 ESP 设备固件
5. **HomeKit 集成** — HomeKit Accessory Protocol 需要 mDNS

**不使用 host 模式的限制：**
- 无法自动发现 Chromecast、Sonos 等设备
- 需要手动配置每个集成
- 部分设备追踪功能失效

### Bridge 模式替代方案

如果不需要 mDNS 发现，可以在 `docker-compose.yml` 中：
1. 注释掉当前的 `homeassistant` 服务定义
2. 取消注释标记为 "Bridge Mode Alternative" 的服务定义
3. Home Assistant 将通过 Traefik 反代访问：`https://ha.<DOMAIN>`

## 前置条件

- Docker >= 24.0 with Compose v2 plugin
- `proxy` Docker network 已创建 (`docker network create proxy`)
- Zigbee USB 适配器（如 Sonoff Zigbee 3.0 USB Dongle Plus）
- 基础设施栈（Traefik）已部署

## 快速开始

### 1. 配置环境变量

```bash
cd stacks/home-automation
cp .env.example .env
```

编辑 `.env` 文件，修改以下关键配置：

```bash
# 必须修改
DOMAIN=yourdomain.com
MQTT_PASSWORD=<强密码>
ZIGBEE_SERIAL_DEVICE=/dev/ttyUSB0  # 你的 Zigbee 适配器路径
```

### 2. 生成 Mosquitto 密码文件

```bash
# 替换 .env 中的 MQTT_PASSWORD 后，生成密码文件
docker run --rm -v $(pwd)/config/mosquitto:/mosquitto/config \
  eclipse-mosquitto:2.0.19 \
  mosquitto_passwd -c -b /mosquitto/config/passwd \
  homeassistant YOUR_PASSWORD_HERE

# 添加其他用户
docker run --rm -v $(pwd)/config/mosquitto:/mosquitto/config \
  eclipse-mosquitto:2.0.19 \
  mosquitto_passwd -b /mosquitto/config/passwd \
  zigbee2mqtt YOUR_PASSWORD_HERE

docker run --rm -v $(pwd)/config/mosquitto:/mosquitto/config \
  eclipse-mosquitto:2.0.19 \
  mosquitto_passwd -b /mosquitto/config/passwd \
  nodered YOUR_PASSWORD_HERE

docker run --rm -v $(pwd)/config/mosquitto:/mosquitto/config \
  eclipse-mosquitto:2.0.19 \
  mosquitto_passwd -b /mosquitto/config/passwd \
  esphome YOUR_PASSWORD_HERE
```

### 3. 检查 Zigbee 适配器

```bash
# 查看可用的串口设备
ls -la /dev/ttyUSB* /dev/ttyACM*

# 确保当前用户有权限访问
sudo usermod -aG dialout $USER
# 重新登录后生效
```

### 4. 启动服务

```bash
docker compose up -d
```

### 5. 验证服务状态

```bash
# 检查所有容器状态
docker compose ps

# 检查健康状态
docker compose ps --format "table {{.Name}}\t{{.Status}}"

# 查看日志
docker compose logs -f
```

## 配置说明

### Zigbee2MQTT 首次配置

启动后访问 Zigbee2MQTT Web UI，配置 MQTT 连接：

```yaml
# Zigbee2MQTT 配置（通过 Web UI 或 /app/data/configuration.yaml）
mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://mosquitto:1883
  user: zigbee2mqtt
  password: YOUR_PASSWORD_HERE

serial:
  port: /dev/ttyUSB0

advanced:
  network_key: GENERATE  # 首次启动自动生成
  pan_id: GENERATE
```

### Home Assistant MQTT 集成

1. 打开 Home Assistant → 设置 → 设备与服务
2. 添加集成 → MQTT
3. 配置：
   - Broker: `localhost`（host 模式）或 `mosquitto`（bridge 模式）
   - Port: `1883`
   - Username: `homeassistant`
   - Password: `<你的密码>`

### Node-RED MQTT 连接

1. 打开 Node-RED → 添加 MQTT 节点
2. 配置连接：
   - Server: `mosquitto`
   - Port: `1883`
   - Username: `nodered`
   - Password: `<你的密码>`

### ESPHome 首次使用

1. 访问 `http://<host_ip>:6052`
2. 创建新设备或导入现有配置
3. ESPHome 通过 host 网络可直接进行 OTA 无线更新

## 国内网络适配

如遇到镜像拉取慢，使用国内镜像源：

```bash
# 替换 ghcr.io 镜像
# Home Assistant
ghcr.io/home-assistant/home-assistant:2024.9.3
→ swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/home-assistant/home-assistant:2024.9.3

# ESPHome
ghcr.io/esphome/esphome:2024.9.3
→ swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/esphome/esphome:2024.9.3
```

在 `docker-compose.yml` 中取消注释 CN alternative 镜像行，并注释原始镜像行。

## 端口说明

| 端口 | 协议 | 服务 | 说明 |
|------|------|------|------|
| 8123 | HTTP | Home Assistant | Web UI（host 模式） |
| 1883 | MQTT | Mosquitto | MQTT 消息协议 |
| 9001 | WS | Mosquitto | MQTT WebSocket |
| 1880 | HTTP | Node-RED | Web UI（Traefik 反代） |
| 8080 | HTTP | Zigbee2MQTT | Web UI（Traefik 反代） |
| 6052 | HTTP | ESPHome | Web UI（host 模式） |

## 常见问题

### Q: Zigbee2MQTT 无法连接到串口设备

```bash
# 检查设备是否存在
ls -la /dev/ttyUSB*

# 检查权限
sudo usermod -aG dialout $USER
# 或临时：sudo chmod 666 /dev/ttyUSB0

# 检查是否被其他程序占用
sudo fuser /dev/ttyUSB0
```

### Q: Home Assistant 无法发现设备

确保使用 `network_mode: host`。如果使用 bridge 模式，需要手动配置集成。

### Q: Mosquitto 连接被拒绝

```bash
# 检查密码文件是否正确生成
docker exec mosquitto cat /mosquitto/config/passwd

# 重新生成密码文件
docker run --rm -v $(pwd)/config/mosquitto:/mosquitto/config \
  eclipse-mosquitto:2.0.19 \
  mosquitto_passwd -c -b /mosquitto/config/passwd mqttuser mqttPass123
```

### Q: ESPHome OTA 更新失败

确保 ESPHome 使用 host 网络模式，且 ESP 设备与服务器在同一局域网。

## 数据持久化

所有数据存储在 Docker volumes 中：

| Volume | 服务 | 内容 |
|--------|------|------|
| `ha-config` | Home Assistant | 配置、自动化、设备数据 |
| `mosquitto-data` | Mosquitto | 持久化消息 |
| `mosquitto-log` | Mosquitto | 日志 |
| `node-red-data` | Node-RED | 流程、配置 |
| `zigbee2mqtt-data` | Zigbee2MQTT | 设备配对、配置 |
| `esphome-data` | ESPHome | 设备固件配置 |

## License

MIT
