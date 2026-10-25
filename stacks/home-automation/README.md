# Home Automation Stack

家庭自动化栈：Home Assistant + Node-RED + Mosquitto + Zigbee2MQTT + ESPHome。

## 服务

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| homeassistant | `ghcr.io/home-assistant/home-assistant:2024.9.3` | host 网络 | 智能家居中枢 |
| nodered | `nodered/node-red:4.0.3` | 1880 | 可视化流程编排 |
| mosquitto | `eclipse-mosquitto:2.0.19` | 1883 | MQTT Broker |
| zigbee2mqtt | `koenkk/zigbee2mqtt:1.40.2` | 8080 | Zigbee 设备网关 |
| esphome | `ghcr.io/esphome/esphome:2024.9.3` | 6052 | ESP 设备固件管理 |

## 为什么 Home Assistant 使用 host 网络

Home Assistant 需要自动发现局域网内的设备，依赖以下协议：

- **mDNS / Bonjour**（`224.0.0.251:5353`）：发现 HomeKit、Chromecast、打印机等设备；
- **UPnP / SSDP**（`239.255.255.250:1900`）：发现路由器、媒体设备；
- **DHCP 广播**：识别设备上线/离线。

这些协议都基于组播或广播，Docker 默认的 bridge 网络不会转发组播，容器内无法完成设备发现，只能手工填写 IP。因此 HA 使用 `network_mode: host`。

### bridge 模式替代方案（功能受限）

`docker-compose.yml` 中已注释掉 bridge 配置，启用方式：注释掉 `network_mode: host`，取消 `networks` 与 `ports` 的注释。

限制：

- 无法自动发现设备，需手工配置 IP；
- HomeKit / Cast / DLNA 集成基本不可用；
- 无法使用 DHCP 监听；
- 端口映射后 HA 认为自己在 `8123` 之外的地址，部分集成回调地址需手工修正。

## 部署

```bash
cp .env.example .env
# 生成 MQTT 密码文件（必须，否则 mosquitto 启动失败）
./scripts/setup-mosquitto.sh
docker compose up -d
```

首次访问：

- Home Assistant: http://<host>:8123
- Node-RED: http://<host>:1880
- Zigbee2MQTT: http://<host>:8080
- ESPHome: http://<host>:6052

## Mosquitto 安全配置

- `allow_anonymous false`，所有客户端必须认证；
- 密码文件位于 `data/mosquitto/passwd`，由 `scripts/setup-mosquitto.sh` 通过 `mosquitto_passwd` 生成；
- 新增用户：`./scripts/setup-mosquitto.sh <user> <password>`（不带 `-c` 追加）；
- 修改 `.env` 中的 `MQTT_USER` / `MQTT_PASSWORD` 后需同步更新 Zigbee2MQTT 配置与 Node-RED 连接凭据。

## Zigbee 设备

1. 将协调器接入宿主机，确认设备路径（如 `/dev/ttyUSB0`）；
2. 在 `.env` 中设置 `ZIGBEE_DEVICE`；
3. 建议用 `/dev/serial/by-id/...` 固定路径，避免重启后编号变化；
4. 配对设备时把 `zigbee2mqtt/configuration.yaml` 的 `permit_join` 改为 `true`，或在 Web UI 中开启。

## 数据目录

所有持久化数据在 `data/`（已 gitignore）：`homeassistant/`、`mosquitto/`、`zigbee2mqtt/`、`nodered/`、`esphome/`。
