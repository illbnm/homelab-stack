# 🏠 Home Automation Stack

> HomeLab Stack — 家庭自动化服务栈

## 📋 服务清单

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| Home Assistant | `ghcr.io/home-assistant/home-assistant:2024.9.3` | 8123 | 智能家居中枢 |
| Node-RED | `nodered/node-red:4.0.3` | 1880 | 流程自动化 |
| Mosquitto | `eclipse-mosquitto:2.0.19` | 1883/8883/9001 | MQTT 消息代理 |
| Zigbee2MQTT | `koenkk/zigbee2mqtt:1.40.2` | 8080 (前端) | Zigbee 网关 |
| ESPHome | `ghcr.io/esphome/esphome:2024.9.3` | 6052 | IoT 设备编程 |

## 🚀 前置准备

### 1. 启动基础架构

```bash
# 先启动基础服务（Traefik 等）
docker compose -f docker-compose.base.yml up -d

# 创建共享网络（如果还没有）
docker network create proxy
```

### 2. 启动 Home Automation 栈

```bash
cd stacks/home-automation

# 复制并编辑环境变量
cp .env.example .env
nano .env  # 编辑配置

# 首次启动前先生成 MQTT 认证
../scripts/setup-home-automation.sh

# 启动所有服务
docker compose up -d
```

### 3. 配置 USB 设备（Zigbee USB 适配器）

```bash
# 查找你的 Zigbee USB 设备
ls -l /dev/serial/by-id/

# 编辑 .env 文件，设置 ZIGBEE_USB_DEVICE
# 例如：ZIGBEE_USB_DEVICE=/dev/ttyACM0
```

### 4. 配置 Mosquitto 认证

```bash
# 运行认证配置脚本
../scripts/setup-home-automation.sh

# 或手动创建用户
docker exec mosquitto mosquitto_passwd -c /mosquitto/config/passwords ha yourpassword
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/passwords nodered noderedpassword
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/passwords zigbee2mqtt zigbee2mqttpassword
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/passwords esphome esphomepassword
```

## 🌐 访问地址

| 服务 | 地址 |
|------|------|
| Home Assistant | `http://homeassistant:8123` 或 `http://ha.${DOMAIN}` |
| Node-RED | `https://nodered.${DOMAIN}` |
| Mosquitto | `mqtt://mosquitto:1883` (内网) |
| Zigbee2MQTT 前端 | `https://zigbee.${DOMAIN}` |
| ESPHome | `https://esphome.${DOMAIN}` |

## ⚙️ 配置说明

### Home Assistant

- **MQTT 集成**：自动发现 MQTT 设备（`homeassistant/#`）
- **Zigbee2MQTT**：通过 ZHA 集成或 MQTT 自动发现连接
- **Node-RED**：通过 `nodered` 集成连接
- **ESPHome**：通过 ESPHome 集成连接

**配置文件**：
- `config/homeassistant/configuration.yaml` — 主配置
- `config/homeassistant/mqtt.yaml` — MQTT 配置
- `config/homeassistant/secrets.yaml` — 密码配置
- `config/homeassistant/automations_examples.yaml` — 自动化示例

### Node-RED

- **MQTT Broker**：连接 `mqtt://mosquitto:1883`，使用 `nodered` 用户
- **Home Assistant**：通过 API 或 MQTT 连接
- **持久化**：数据存储在 `node-red-data` volume

**预置流程**：
- `config/node-red/flows.json` — 示例流程（MQTT 桥接、HA 监听、Zigbee 监控）

### Mosquitto

- **MQTT**：端口 `1883`（非加密）、`8883`（TLS）
- **WebSocket**：端口 `9001`（用于 Web 端 MQTT 客户端）
- **认证**：默认启用，用户名密码见 `.env`
- **ACL**：基于用户的读写权限控制

### Zigbee2MQTT

- **MQTT 连接**：使用 TLS 连接 `mqtts://mosquitto:8883`
- **前端**：`https://zigbee.${DOMAIN}`（需配置 Traefik）
- **Network Key**：在 `.env` 中配置 `ZIGBEE2MQTT_NETWORK_KEY`
- **OTA**：支持从 Zigbee 官方服务器更新设备固件

### ESPHome

- **API 加密**：与 Home Assistant 通信使用加密
- **OTA**：支持无线更新固件
- **配置文件**：`config/esphome/*.yaml`

## 🔐 安全配置

### 生成 Zigbee Network Key

```bash
# 生成随机 Network Key（16字节，hex 编码）
openssl rand -hex 16

# 生成 PAN ID
openssl rand -hex 2

# 生成 Extended PAN ID
openssl rand -hex 8
```

### 生成 ESPHome API 加密密钥

```bash
openssl rand -hex 32
```

### 生成 MQTT 密码

```bash
# 使用 mosquitto_passwd
mosquitto_passwd -c passwords ha yourpassword
```

## 📁 项目文件结构

```
stacks/home-automation/
├── docker-compose.yml       # Docker Compose 配置
├── mosquitto.conf          # Mosquitto 主配置
├── acl.conf                # Mosquitto ACL 规则
├── passwords               # Mosquitto 密码文件（运行时生成）
├── README.md               # 本文件

config/homeassistant/
├── configuration.yaml       # Home Assistant 主配置
├── mqtt.yaml               # MQTT 配置
├── secrets.yaml            # 密码配置
├── automations.yaml        # 自动化配置
├── automations_examples.yaml # 自动化示例
├── scripts.yaml            # 脚本示例
├── scenes.yaml             # 场景示例
└── customize.yaml          # 实体自定义

config/node-red/
├── settings.js             # Node-RED 设置
└── flows.json              # 预置流程示例

config/zigbee2mqtt/
└── configuration.yaml      # Zigbee2MQTT 配置

config/esphome/
├── esphome.yaml            # ESPHome 配置模板
└── secrets.yaml            # ESPHome 密码配置
```

## ✅ 验收检查

1. ✅ 访问 `http://homeassistant:8123` 能打开 Home Assistant 界面
2. ✅ `https://nodered.${DOMAIN}` 能访问 Node-RED 编辑器
3. ✅ Mosquitto 日志无认证错误：`docker logs mosquitto`
4. ✅ Zigbee2MQTT 前端 `https://zigbee.${DOMAIN}` 可访问
5. ✅ ESPHome Dashboard `https://esphome.${DOMAIN}` 可访问
6. ✅ 所有容器健康检查通过：`docker compose ps`

## 🔧 常用命令

```bash
# 查看所有服务状态
docker compose ps

# 查看某个服务日志
docker logs -f homeassistant
docker logs -f mosquitto
docker logs -f zigbee2mqtt

# 重启单个服务
docker compose restart homeassistant

# 重新生成 Mosquitto 密码
./scripts/setup-home-automation.sh

# 进入 Node-RED 容器
docker exec -it node-red bash

# 测试 MQTT 连接
docker exec mosquitto mosquitto_pub -t test -m "hello" -u ha -P yourpassword
docker exec mosquitto mosquitto_sub -t test -u ha -P yourpassword
```

## 📚 相关文档

- [Home Assistant 官方文档](https://www.home-assistant.io/docs/)
- [Node-RED 文档](https://nodered.org/docs/)
- [Mosquitto 文档](https://mosquitto.org/man/mosquitto-conf-5.html)
- [Zigbee2MQTT 文档](https://www.zigbee2mqtt.io/guide/configuration/)
- [ESPHome 文档](https://esphome.io/index.html)
