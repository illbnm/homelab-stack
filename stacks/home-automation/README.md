# 🏠 Home Automation Stack

完整的智能家居自动化栈，支持 Zigbee 设备接入和可视化流程编排。

[![Bounty](https://img.shields.io/badge/BOUNTY-$130-orange.svg)](https://github.com/illbnm/homelab-stack/issues/7)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue.svg)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)]()

## 📦 服务列表

| 服务 | 版本 | 用途 | 端口 |
|------|------|------|------|
| **Home Assistant** | 2024.9.3 | 智能家居中枢 | 8123 |
| **Node-RED** | 4.0.3 | 可视化流程编排 | 1880 |
| **Mosquitto** | 2.0.19 | MQTT Broker | 1883, 9001 |
| **Zigbee2MQTT** | 1.40.2 | Zigbee 设备网关 | 8080 |
| **ESPHome** | 2024.9.3 | ESP 设备固件管理 | 6053 |

---

## 🚀 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack
```

### 2. 创建配置目录

```bash
mkdir -p config/mosquitto/data config/mosquitto/log
```

### 3. 配置 Mosquitto 认证

```bash
# 创建密码文件
docker run --rm -v $(pwd)/config/mosquitto:/mosquitto eclipse-mosquitto:2.0.19 \
  mosquitto_passwd -c /mosquitto/passwordfile homeassistant

# 输入密码后，创建其他用户
docker run --rm -v $(pwd)/config/mosquitto:/mosquitto eclipse-mosquitto:2.0.19 \
  mosquitto_passwd /mosquitto/passwordfile nodered
```

### 4. 配置 Zigbee2MQTT

编辑 `config/zigbee2mqtt/configuration.yaml`，更新 MQTT 用户名和密码：

```yaml
mqtt:
  user: zigbee2mqtt
  password: your_password_here
```

### 5. 配置 ESPHome Secrets

编辑 `config/esphome/secrets.yaml`：

```yaml
wifi_ssid: "YourWiFiSSID"
wifi_password: "YourWiFiPassword"
api_key: "your_api_key_here"
ota_password: "your_ota_password_here"
```

### 6. 启动服务

```bash
docker-compose up -d
```

### 7. 访问服务

- **Home Assistant**: http://localhost:8123
- **Node-RED**: http://localhost:1880
- **Zigbee2MQTT**: http://localhost:8080
- **ESPHome**: http://localhost:6053

---

## 🔧 配置说明

### Home Assistant 网络模式

**必须使用 `network_mode: host`**，原因如下：

1. **mDNS 设备发现**: Home Assistant 使用 mDNS (Multicast DNS) 自动发现本地网络设备
   - Google Cast (Chromecast)
   - Apple AirPlay
   - Philips Hue
   - Sonos 扬声器

2. **UPnP 设备发现**: 某些设备使用 UPnP 协议进行通信
   - 路由器
   - 媒体服务器
   - 网络存储设备

3. **广播和多播**: 某些智能家居协议需要广播/多播通信
   - MQTT Discovery
   - Zigbee 协调器发现

**Bridge 模式的限制**：

如果必须使用 bridge 模式（例如在某些容器编排环境中），请取消 `docker-compose.yml` 中 `homeassistant-bridge` 的注释，但请注意：

- ❌ 无法自动发现 mDNS 设备
- ❌ 无法自动发现 UPnP 设备
- ❌ 需要手动配置设备 IP 地址
- ✅ 可以使用 MQTT 发现设备
- ✅ 可以使用 Webhook 集成

---

### Mosquitto 安全配置

Mosquitto 配置了以下安全措施：

1. **禁用匿名访问**
   ```conf
   allow_anonymous false
   ```

2. **密码认证**
   ```bash
   # 创建用户
   mosquitto_passwd -c passwordfile username
   ```

3. **WebSocket 支持**
   - TCP: 1883
   - WebSocket: 9001

4. **持久化**
   - 数据存储在 `config/mosquitto/data`
   - 日志存储在 `config/mosquitto/log`

---

### Zigbee2MQTT 配置

1. **串口设备**
   - 默认使用 `/dev/ttyUSB0`
   - 如果使用其他设备，修改 `docker-compose.yml` 中的 `devices` 配置

2. **网络配置**
   - 生成唯一网络密钥
   - 使用默认 Zigbee 通道 11

3. **设备加入**
   - 默认允许新设备加入 (`permit_join: true`)
   - 生产环境建议设为 `false`

---

## 📊 系统架构

```
┌─────────────────────────────────────────────────────┐
│                   Home Assistant                     │
│              (智能家居中枢 - host 网络)                │
│                      端口: 8123                      │
└──────────┬───────────────────┬──────────────────────┘
           │                   │
           │                   │
    ┌──────▼──────┐    ┌──────▼──────┐
    │  Node-RED   │    │  Mosquitto  │
    │ (流程编排)   │◄───┤ (MQTT Broker)│
    │ 端口: 1880   │    │ 端口: 1883  │
    └─────────────┘    └──────┬──────┘
                               │
                        ┌──────▼──────┐
                        │ Zigbee2MQTT │
                        │ (Zigbee网关) │
                        │ 端口: 8080   │
                        └──────┬──────┘
                               │
                        ┌──────▼──────┐
                        │   ESPHome   │
                        │  (ESP管理)   │
                        │ 端口: 6053   │
                        └─────────────┘
```

---

## 🔐 安全建议

1. **修改默认密码**
   - Mosquitto 用户密码
   - Zigbee2MQTT 网络密钥
   - ESPHome API 密钥

2. **网络隔离**
   - 使用独立的 VLAN
   - 配置防火墙规则
   - 限制服务暴露

3. **定期备份**
   - Home Assistant 配置
   - Mosquitto 数据
   - Zigbee2MQTT 设备列表

---

## 📝 使用示例

### Home Assistant 集成 Zigbee2MQTT

1. Home Assistant → Settings → Devices & Services
2. 添加 "MQTT" 集成
3. 输入 Mosquitto 连接信息
4. 自动发现 Zigbee2MQTT 设备

### Node-RED 连接 MQTT

1. 添加 "mqtt in" 节点
2. 配置 MQTT Broker: `mosquitto:1883`
3. 订阅主题: `zigbee2mqtt/#`
4. 可视化流程编排

---

## 🛠️ 故障排查

### Home Assistant 无法发现设备

- ✅ 确认使用 `network_mode: host`
- ✅ 检查防火墙设置
- ✅ 确认设备在同一网络

### Mosquitto 连接失败

```bash
# 检查日志
docker logs mosquitto

# 测试连接
mosquitto_sub -h localhost -t test -u homeassistant -P password
```

### Zigbee2MQTT 找不到协调器

```bash
# 检查 USB 设备
ls -la /dev/ttyUSB*

# 权限问题
sudo chmod 666 /dev/ttyUSB0
```

---

## 📚 参考文档

- [Home Assistant 官方文档](https://www.home-assistant.io/docs/)
- [Node-RED 文档](https://nodered.org/docs/)
- [Mosquitto 文档](https://mosquitto.org/documentation/)
- [Zigbee2MQTT 文档](https://www.zigbee2mqtt.io/)
- [ESPHome 文档](https://esphome.io/)

---

## 📄 License

MIT License

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

**🎉 享受您的智能家居之旅！**
