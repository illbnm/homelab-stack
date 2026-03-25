# Home Automation Stack

智能家居自动化服务栈，支持 Zigbee 设备接入和可视化流程编排。

## 服务架构

```
┌─────────────────────────────────────────────────────────┐
│                Home Automation Stack                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   Home Assistant                                         │
│   ├── 智能家居中枢                                      │
│   ├── 支持 2000+ 设备集成                               │
│   └── 网络模式: host (mDNS/UPnP 发现)                  │
│                                                          │
│   Node-RED                                              │
│   ├── 可视化流程编排                                    │
│   └── MQTT 消息处理                                     │
│                                                          │
│   Mosquitto                                             │
│   ├── MQTT Broker                                       │
│   └── WebSocket 支持                                    │
│                                                          │
│   Zigbee2MQTT                                           │
│   ├── Zigbee 设备网关                                   │
│   └── 支持 2800+ 设备                                   │
│                                                          │
│   ESPHome                                               │
│   ├── ESP 设备固件管理                                   │
│   └── YAML 配置编译                                     │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 服务列表

| 服务 | 端口 | 说明 |
|------|------|------|
| Home Assistant | 8123 | 智能家居中枢 |
| Node-RED | 1880 | 流程编排 |
| Mosquitto | 1883, 9001 | MQTT Broker |
| Zigbee2MQTT | 8080 | Zigbee 网关 |
| ESPHome | 6052 | ESP 固件管理 |

## 快速开始

### 1. 配置环境变量

```bash
cd homelab-stack
cp stacks/home-automation/.env.example stacks/home-automation/.env 2>/dev/null || true
```

### 2. 启动服务

```bash
docker compose -f stacks/home-automation/docker-compose.yml up -d
```

### 3. 访问服务

| 服务 | 地址 | 凭据 |
|------|------|------|
| Home Assistant | http://ha.${DOMAIN}:8123 | 首次配置账户 |
| Node-RED | http://nodered.${DOMAIN} | 无需认证 |
| ESPHome | http://esphome.${DOMAIN}:6052 | 无需认证 |

## Home Assistant 配置

### 网络模式

Home Assistant 使用 `network_mode: host` 以支持：
- mDNS/UPnP 设备发现
- 本地网络设备直接访问
- Bonjour/Avahi 服务发现

如果不需要这些功能，可以注释掉 `network_mode: host` 并取消注释 `networks` 部分，使用 bridge 模式。

### 集成 MQTT

在 Home Assistant 中添加 Mosquitto 集成：

1. 设置 -> 设备与服务 -> 添加集成
2. 搜索 "MQTT"
3. 配置：
   - Broker: `mosquitto`
   - Port: `1883`

### Zigbee2MQTT 配置

Zigbee2MQTT 需要连接到实际的 Zigbee USB 设备。编辑 `docker-compose.yml`：

```yaml
devices:
  - /dev/serial/by-id/your-zigbee-device:/dev/zigbee
```

查找 Zigbee 设备：
```bash
ls -la /dev/serial/by-id/
```

## Node-RED 配置

### MQTT Broker 连接

在 Node-RED 中配置 MQTT 节点：

1. 添加 MQTT Broker 节点
2. 配置：
   - Server: `mosquitto`
   - Port: `1883`

### Home Assistant 集成

安装 `node-red-contrib-home-assistant-websocket` 包来连接 Home Assistant。

## Mosquitto 安全配置

### 创建用户密码文件

```bash
# 进入 mosquitto 容器
docker exec -it mosquitto sh

# 创建用户 (交互式)
mosquitto_passwd -c /mosquitto/config/pwfile username

# 添加更多用户
mosquitto_passwd /mosquitto/config/pwfile another_user

# 重启服务使配置生效
docker restart mosquitto
```

### 配置 Home Assistant 使用认证

```yaml
# Home Assistant configuration.yaml
mqtt:
  broker: mosquitto
  port: 1883
  username: homeassistant
  password: your_password
```

## Zigbee2MQTT 配置

Zigbee2MQTT 配置文件位于容器内的 `/app/data/configuration.yaml`：

```yaml
homeassistant: true
permit_join: true
frontend:
  port: 8080
mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://mosquitto:1883
serial:
  port: /dev/zigbee
```

### 允许新设备加入

```bash
# 临时允许加入
curl -X PUT http://localhost:8080/bridge/permissions

# 永久允许 (编辑 configuration.yaml)
permit_join: true
```

## ESPHome 配置

### 添加新设备

```bash
# 进入 ESPHome 容器
docker exec -it esphome bash

# 创建新配置
esphome configlivingroom.yaml wizard
```

### 编译和上传

```bash
# 编译
esphome config/mydevice.yaml compile

# 上传 (通过 USB)
esphome config/mydevice.yaml upload --device /dev/ttyUSB0

# 无线更新
esphome config/mydevice.yaml run
```

## 故障排除

### Home Assistant 无法发现设备

1. 确认使用 host 网络模式
2. 检查防火墙允许 mDNS (5353/UDP)
3. 确认设备与服务器在同一网络

### Zigbee2MQTT 连接失败

```bash
# 检查 Zigbee 设备
ls -la /dev/serial/by-id/

# 查看 Zigbee2MQTT 日志
docker logs zigbee2mqtt
```

### Node-RED 无法连接 MQTT

```bash
# 检查 Mosquitto 状态
docker logs mosquitto

# 测试 MQTT 连接
mosquitto_pub -h mosquitto -p 1883 -t test -m "hello"
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| TZ | Asia/Shanghai | 时区 |
| PUID | 1000 | 用户 ID |
| PGID | 1000 | 组 ID |

## 相关文档

- [Home Assistant 文档](https://www.home-assistant.io/docs/)
- [Node-RED 文档](https://nodered.org/docs/)
- [Mosquitto 文档](https://mosquitto.org/man/mosquitto-conf-8.html)
- [Zigbee2MQTT 文档](https://www.zigbee2mqtt.io/)
- [ESPHome 文档](https://esphome.io/)
