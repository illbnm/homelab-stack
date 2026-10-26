# Home Automation 栈

家庭自动化栈，包含 Home Assistant、Node-RED、Mosquitto、Zigbee2MQTT、ESPHome。

| 服务 | 镜像 | 端口 | 用途 |
|------|------|------|------|
| Home Assistant | `ghcr.io/home-assistant/home-assistant:2024.9.3` | 8123（host 网络） | 智能家居中枢 |
| Node-RED | `nodered/node-red:4.0.3` | 1880 | 可视化流程编排 |
| Mosquitto | `eclipse-mosquitto:2.0.19` | 1883 / 9001 | MQTT Broker |
| Zigbee2MQTT | `koenkk/zigbee2mqtt:1.40.2` | 8080 | Zigbee 设备网关 |
| ESPHome | `ghcr.io/esphome/esphome:2024.9.3` | 6052 | ESP 设备固件管理 |

## 快速开始

```bash
cp .env.example .env
$EDITOR .env                 # 至少设置 MQTT_PASSWORD
../../scripts/setup-mosquitto.sh
docker compose up -d
```

启动后访问：

- Home Assistant: `http://<host>:8123`
- Node-RED: `http://<host>:1880`
- Zigbee2MQTT: `http://<host>:8080`
- ESPHome: `http://<host>:6052`

## 为什么 Home Assistant 使用 host 网络

Home Assistant 的设备自动发现依赖 mDNS（组播 `224.0.0.251:5353`）和 SSDP/UPnP 广播。
Docker 默认的 bridge 网络不转发组播，容器内的发现报文也到不了局域网，
因此 `homeassistant` 服务固定使用 `network_mode: host`：

- mDNS / SSDP 发现可用（HomeKit、Chromecast、打印机、路由器等）
- 无需维护 `ports:` 映射，HA 直接监听宿主机 8123
- HA 通过 `127.0.0.1:1883` 访问 Mosquitto

### bridge 模式替代配置

如果必须使用 bridge（多实例、端口隔离等），在 `docker-compose.yml` 中：

1. 注释掉 `homeassistant` 的 `network_mode: host`
2. 取消 `networks:` 与 `ports:` 的注释

功能限制：

- mDNS/SSDP 自动发现失效，集成需手动填写设备 IP
- HomeKit Bridge、Chromecast、DLNA 等依赖组播的集成基本不可用
- 需要把 MQTT 地址从 `127.0.0.1` 改成 `mosquitto`

## Mosquitto 安全配置

`config/mosquitto/mosquitto.conf` 关闭匿名访问，强制用户名/密码认证，
密码文件由 `scripts/setup-mosquitto.sh` 调用 `mosquitto_passwd` 生成到
`config/mosquitto/passwd`（不入库，必须在首次启动前生成，否则 Broker 无法启动）。

## Zigbee 协调器

默认使用 `/dev/ttyUSB0`，可在 `.env` 中用 `ZIGBEE_SERIAL_PORT` 覆盖。
协调器需要直通给容器，因此 `zigbee2mqtt` 声明了 `devices:`。

## 数据目录

| 宿主机路径 | 说明 |
|------------|------|
| `./config/homeassistant` | Home Assistant 配置 |
| `./config/esphome` | ESPHome 配置 |
| `config/mosquitto/` | Broker 配置与密码文件 |
| 命名卷 `nodered-data` | Node-RED 流程 |
| 命名卷 `zigbee2mqtt-data` | Zigbee2MQTT 数据 |
