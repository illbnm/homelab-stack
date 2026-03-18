# 🏠 Home Automation Stack

智能家居自动化栈，集成 Home Assistant、Node-RED、Mosquitto 和 Zigbee2MQTT。

## 服务概览

| 服务 | 镜像 | 端口 | 用途 | Traefik |
|------|------|------|------|---------|
| Home Assistant | `homeassistant/home-assistant:2024.12.5` | 8123 (host) | 智能家居中枢 | ✅ host 模式直连 |
| Node-RED | `nodered/node-red:3.1.9` | 1883 | 可视化流程编排 | ✅ `nodered.${DOMAIN}` |
| Mosquitto | `eclipse-mosquitto:2.0.20` | 1883 | MQTT Broker | ❌ 仅内部网络 |
| Zigbee2MQTT | `koenkk/zigbee2mqtt:1.40.0` | — | Zigbee 设备桥接 | ❌ 仅内部网络 |

## 网络架构

```
proxy (external)          homeautomation (bridge)
┌──────────────────┐      ┌──────────────────┐
│  Node-RED ◄──────┼──────┤  Node-RED        │
│                  │      │  Mosquitto       │
└──────────────────┘      │  Zigbee2MQTT     │
                          │  Home Assistant  │
                          └──────────────────┘
```

- **proxy**: 外部网络，Traefik 反向代理使用
- **homeautomation**: 内部桥接网络，服务间通信
- **Mosquitto** 仅在 homeautomation 网络，不暴露到 proxy
- **Home Assistant** 使用 host 网络模式（见下方说明）

## Home Assistant 网络模式说明

### 为什么使用 `network_mode: host`？

Home Assistant 需要通过 **mDNS** 和 **UPnP/SSDP** 协议发现和控制设备（如 Chromecast、HomeKit、某些 Zigbee/Z-Wave 适配器）。这些协议依赖多播（multicast），Docker bridge 网络默认**不支持多播**。

使用 host 模式可以让 HA 直接访问宿主机的网络栈，完整支持所有设备发现协议。

### Bridge 模式替代

`docker-compose.yml` 中提供了注释掉的 bridge 模式配置。如果启用：

- ✅ 可通过 Traefik 反代访问（`ha.${DOMAIN}`）
- ❌ **不支持** mDNS/UPnP 设备发现
- ❌ Chromecast、AirPlay、部分智能家居桥接功能受限
- ❌ 某些 Zigbee 适配器可能无法正常工作

## 前置准备

1. **Zigbee 适配器**: 确认 USB Zigbee 适配器设备路径（默认 `/dev/ttyACM0`）
   ```bash
   ls /dev/ttyACM*
   ```
   如路径不同，修改 `docker-compose.yml` 中 `zigbee2mqtt.devices`。

2. **Mosquitto 配置**: 确保 `config/mosquitto/mosquitto.conf` 存在（仓库已提供）。

3. **Traefik 网络**: 确保 `proxy` 外部网络已创建：
   ```bash
   docker network create proxy
   ```

## 快速启动

```bash
cd stacks/home-automation
cp .env.example .env
# 编辑 .env，设置 DOMAIN=yourdomain.com
docker compose up -d
```

## 初始配置

### Home Assistant
- 访问 `http://<HOST_IP>:8123` 完成初始化向导
- 添加 Mosquitto MQTT 集成（broker: `mosquitto`, port: `1883`）
- 添加 Zigbee2MQTT 集成

### Node-RED
- 访问 `https://nodered.${DOMAIN}`
- 安装 `node-red-contrib-home-assistant` 插件连接 HA
- 配置 MQTT 节点连接 `mosquitto:1883`

### Zigbee2MQTT
- 编辑 `zigbee2mqtt_data/configuration.yaml` 设置适配器和 MQTT 参数
- 前端访问需通过 Node-RED 或 HA 集成

## 数据持久化

所有数据存储在 Docker 命名卷中：

| 卷 | 说明 |
|----|------|
| `ha_config` | Home Assistant 配置和自定义组件 |
| `nodered_data` | Node-RED 流程和节点 |
| `mosquitto_data` | MQTT 持久化消息 |
| `mosquitto_log` | Mosquitto 日志 |
| `zigbee2mqtt_data` | Zigbee2MQTT 配置和设备数据库 |

## 维护

```bash
# 查看日志
docker compose logs -f homeassistant
docker compose logs -f nodered
docker compose logs -f mosquitto
docker compose logs -f zigbee2mqtt

# 备份
docker run --rm -v ha_config:/data -v $(pwd):/backup alpine tar czf /backup/ha_config.tar.gz -C /data .

# 更新
docker compose pull
docker compose up -d
```
