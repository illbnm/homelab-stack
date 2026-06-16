# Home Automation Stack — $200 Bounty

## 服务

| 服务 | 镜像 | 用途 |
|------|------|------|
| Home Assistant | ghcr.io/home-assistant/home-assistant:2024.10.4 | 智能家居中枢 |
| Mosquitto | eclipse-mosquitto:2.0.19 | MQTT 消息代理 |
| Zigbee2MQTT | koenkk/zigbee2mqtt:1.40.2 | Zigbee 设备网关 |
| ESPHome | ghcr.io/esphome/esphome:2024.9.3 | ESP 设备固件管理 |

## 快速开始

```bash
# 1. 配置环境变量
cp .env.example .env
nano .env

# 2. 创建 MQTT 密码
bash scripts/home-assistant-setup.sh

# 3. 启动
docker compose up -d

# 4. 访问 Home Assistant
open http://homeassistant.local:8123
```

## 核心设计

- Home Assistant 使用 network_mode: host（mDNS/UPnP 设备发现需要）
- 桥接模式替代配置已注释在 docker-compose.yml 中
- Mosquitto 配置了 TLS-ready 的 MQTT over WebSocket
- Zigbee2MQTT 通过 /dev/ttyACM0 直连 Zigbee 协调器
- ESPHome 通过 Traefik 反向代理可访问
- 所有服务配置 Watchtower 自动更新

## 验收清单

- [ ] Home Assistant 启动并可访问
- [ ] Mosquitto MQTT 代理正常运行
- [ ] Zigbee2MQTT 连接 Zigbee 协调器
- [ ] ESPHome 通过 esphome.${DOMAIN} 可访问
