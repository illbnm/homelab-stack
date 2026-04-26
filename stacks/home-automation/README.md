# Home Automation Stack / 智能家居自动化栈

Complete home automation platform with Home Assistant, Node-RED, Zigbee2MQTT, Mosquitto MQTT broker, and ESPHome.

完整的智能家居自动化平台，包含 Home Assistant、Node-RED、Zigbee2MQTT、Mosquitto MQTT 代理和 ESPHome。

## Services / 服务列表

| Service | Version | URL | Purpose / 用途 |
|---------|---------|-----|----------------|
| Home Assistant | 2024.11.3 | `ha.<DOMAIN>` | Home automation hub / 家居自动化中枢 |
| Node-RED | 4.0.5 | `nodered.<DOMAIN>` | Flow-based automation / 可视化流程自动化 |
| Zigbee2MQTT | 1.41.0 | `zigbee.<DOMAIN>` | Zigbee device gateway / Zigbee 设备网关 |
| Mosquitto | 2.0.20 | — (port 1883) | MQTT broker / MQTT 消息代理 |
| ESPHome | 2024.11.1 | `esphome.<DOMAIN>` | DIY IoT firmware builder / DIY 物联网固件编译器 |

## Architecture / 架构图

```
Internet / 互联网
    |
    v
[Traefik :443] ---- TLS termination (Let's Encrypt)
    |
    +---> ha.<DOMAIN>       --> Home Assistant :8123
    +---> nodered.<DOMAIN>  --> Node-RED :1880
    +---> zigbee.<DOMAIN>   --> Zigbee2MQTT :8080
    +---> esphome.<DOMAIN>  --> ESPHome :6052
    |
[proxy network] <-- shared Docker network

                  [home-automation network] <-- internal MQTT traffic
                       |
         +-------------+-------------+-------------+
         |             |             |             |
    Mosquitto     Zigbee2MQTT   Node-RED      ESPHome
    :1883/:9001       |             |             |
         |             |             |             |
         +------+------+------+------+------+------+
                |                    |
           MQTT Protocol        MQTT Protocol
                |                    |
    +-----+----+----+-----+    +---------+
    |     |    |    |     |    | ESP8266  |
   Zigbee | Sensors |  Switches | ESP32   |
  Devices |         |           | Devices |
          |         |           +---------+
     [USB Zigbee Coordinator]
     (CC2652/Sonoff ZBDongle)

LAN Devices --> :1883 (MQTT) --> Mosquitto --> Home Assistant
Webhooks   --> :8123 (/api/webhook/) --> Home Assistant Automations
```

## Prerequisites / 前置条件

- Base stack running (`stacks/base/` with Traefik) / 基础栈已运行
- Docker >= 24.0 with Compose v2 / Docker >= 24.0 且安装 Compose v2
- Domain DNS configured / 域名 DNS 已配置
- (Optional) USB Zigbee coordinator for Zigbee2MQTT / （可选）USB Zigbee 协调器

## Quick Start / 快速开始

```bash
# 1. Navigate to stack directory / 进入栈目录
cd stacks/home-automation

# 2. Symlink root .env / 链接根目录 .env
ln -sf ../../.env .env

# 3. Fill in HOME AUTOMATION variables in .env
#    填写 .env 中 HOME AUTOMATION 相关变量
nano ../../.env

# 4. Initialize MQTT passwords / 初始化 MQTT 密码
chmod +x setup-mqtt.sh
./setup-mqtt.sh

# 5. Start all services / 启动所有服务
docker compose up -d

# 6. Check health / 检查健康状态
docker compose ps
```

### Local Development / 本地开发

```bash
# Start without TLS (plain HTTP, direct ports)
# 无 TLS 启动（纯 HTTP，直接端口访问）
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d

# Access services directly:
# Home Assistant:  http://localhost:8123
# Node-RED:        http://localhost:1880
# Zigbee2MQTT:     http://localhost:8080
# ESPHome:         http://localhost:6052
```

## Configuration / 配置说明

### Environment Variables / 环境变量

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | — | Base domain (e.g. `home.example.com`) |
| `TZ` | Yes | `Asia/Shanghai` | Timezone / 时区 |
| `MQTT_USER` | Yes | `homeassistant` | MQTT admin username / MQTT 管理员用户名 |
| `MQTT_PASSWORD` | Yes | — | MQTT password (shared by all services) / MQTT 密码 |
| `MQTT_PORT` | No | `1883` | MQTT host port / MQTT 主机端口 |
| `MQTT_WS_PORT` | No | `9001` | MQTT WebSocket port / WebSocket 端口 |
| `NODE_RED_CREDENTIAL_SECRET` | Yes | — | Encryption key for Node-RED credentials / Node-RED 凭据加密密钥 |
| `ZIGBEE_ADAPTER_PATH` | No | `/dev/ttyUSB0` | Zigbee USB adapter device path / Zigbee USB 适配器路径 |
| `PUID` | No | `1000` | User ID for Node-RED / Node-RED 用户 ID |
| `PGID` | No | `1000` | Group ID for Node-RED / Node-RED 组 ID |

### MQTT ACL (Access Control) / MQTT 访问控制

The ACL file (`config/mosquitto/acl.conf`) controls topic-level permissions per user:

ACL 文件 (`config/mosquitto/acl.conf`) 按用户控制主题级别权限：

| User | Permissions | Topics |
|------|-------------|--------|
| `homeassistant` | read/write | `#` (all) |
| `zigbee2mqtt` | read/write | `zigbee2mqtt/#`, read `homeassistant/#` |
| `nodered` | read/write | `#` (all) |
| `esphome` | read/write | `esphome/#`, read `homeassistant/#` |

To add a custom device user / 添加自定义设备用户:

```bash
# Add user to password file / 添加用户到密码文件
docker exec mosquitto mosquitto_passwd /mosquitto/config/passwd mydevice

# Then add ACL rules in config/mosquitto/acl.conf:
# user mydevice
# topic readwrite devices/mydevice/#

# Restart to apply / 重启生效
docker compose restart mosquitto
```

## Zigbee Coordinator Setup / Zigbee 协调器设置

### Supported Adapters / 支持的适配器

| Adapter | Chipset | Device Path | Notes |
|---------|---------|-------------|-------|
| Sonoff ZBDongle-P | CC2652P | `/dev/ttyUSB0` | Recommended / 推荐 |
| Sonoff ZBDongle-E | EFR32MG21 | `/dev/ttyACM0` | Best range / 最佳范围 |
| CC2531 USB | CC2531 | `/dev/ttyACM0` | Legacy, limited capacity / 旧款，容量有限 |
| ConBee II | deCONZ | `/dev/ttyACM0` | Good alternative / 好的替代品 |
| SMLIGHT SLZB-06 | CC2652P | TCP `tcp://IP:6638` | Ethernet, no USB needed / 网口，无需 USB |

### Finding Your Device / 查找设备路径

```bash
# List USB serial devices / 列出 USB 串口设备
ls -la /dev/ttyUSB* /dev/ttyACM* 2>/dev/null

# Detailed device info / 详细设备信息
dmesg | grep -i 'tty\|serial\|cp210x\|ch341\|ftdi'

# By device ID (persistent across reboots) / 按设备 ID（重启不变）
ls -la /dev/serial/by-id/

# Example output:
# /dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_xxxx-if00-port0 -> ../../ttyUSB0
```

### Enable Device Passthrough / 启用设备直通

1. Set `ZIGBEE_ADAPTER_PATH` in `.env`:

```env
# Use by-id path for stability / 使用 by-id 路径保证稳定性
ZIGBEE_ADAPTER_PATH=/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_xxxx-if00-port0
```

2. Uncomment the `devices` section in `docker-compose.yml`:

```yaml
zigbee2mqtt:
    # ...
    devices:
      - ${ZIGBEE_ADAPTER_PATH:-/dev/ttyUSB0}:${ZIGBEE_ADAPTER_PATH:-/dev/ttyUSB0}
```

3. Restart: `docker compose up -d zigbee2mqtt`

### Network-based Zigbee Coordinators / 网络型 Zigbee 协调器

For Ethernet/WiFi coordinators (e.g. SMLIGHT SLZB-06), no USB passthrough is needed:

对于以太网/WiFi 协调器（如 SMLIGHT SLZB-06），不需要 USB 直通：

```env
ZIGBEE_ADAPTER_PATH=tcp://192.168.1.100:6638
```

## Home Assistant Webhook Examples / Home Assistant Webhook 示例

### Automation via Webhook / 通过 Webhook 触发自动化

1. In Home Assistant, create an automation with a **Webhook trigger**:

   在 Home Assistant 中创建一个带 **Webhook 触发器** 的自动化：

```yaml
# configuration.yaml or via UI
automation:
  - alias: "Webhook - Turn on Lights"
    trigger:
      - platform: webhook
        webhook_id: "turn_on_lights_secret123"
        allowed_methods:
          - POST
        local_only: false
    action:
      - service: light.turn_on
        target:
          area_id: living_room
        data:
          brightness_pct: 80
```

2. Trigger from anywhere / 从任何地方触发:

```bash
curl -X POST https://ha.yourdomain.com/api/webhook/turn_on_lights_secret123
```

### Node-RED to Home Assistant / Node-RED 连接 Home Assistant

Install `node-red-contrib-home-assistant-websocket` in Node-RED:

在 Node-RED 中安装 `node-red-contrib-home-assistant-websocket`：

1. Go to Node-RED -> Manage Palette -> Install
2. Search for `node-red-contrib-home-assistant-websocket`
3. Configure the HA server connection:
   - Base URL: `http://homeassistant:8123`
   - Access Token: Generate a Long-Lived Access Token in HA Profile

### MQTT Automation Flow Example / MQTT 自动化流程示例

```
[Zigbee Motion Sensor] --> MQTT --> zigbee2mqtt/living_room/motion
                                         |
                                    [Node-RED]
                                         |
                              +----------+-----------+
                              |                      |
                    [MQTT publish]           [HA webhook call]
                    esphome/led/on          /api/webhook/motion_alert
                              |                      |
                     [ESP32 LED strip]      [HA: send notification]
```

## ESPHome Getting Started / ESPHome 入门

### Create Your First Device / 创建第一个设备

1. Access ESPHome dashboard at `https://esphome.<DOMAIN>`
2. Click "New Device" -> Give it a name
3. Choose ESP32 or ESP8266
4. Edit the generated YAML:

```yaml
esphome:
  name: living-room-sensor
  platform: ESP32
  board: esp32dev

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password

mqtt:
  broker: mosquitto  # Uses internal Docker DNS
  username: esphome
  password: !secret mqtt_password

sensor:
  - platform: dht
    pin: GPIO4
    temperature:
      name: "Living Room Temperature"
    humidity:
      name: "Living Room Humidity"
    update_interval: 60s

binary_sensor:
  - platform: gpio
    pin: GPIO5
    name: "Living Room Motion"
    device_class: motion
```

5. Click "Install" -> choose OTA (WiFi) or USB
6. The device will appear automatically in Home Assistant via MQTT

## CN Mirror Configuration / 国内镜像配置

For users in mainland China, replace image references in `docker-compose.yml`:

中国大陆用户，替换 `docker-compose.yml` 中的镜像源：

| Original Image | CN Mirror |
|----------------|-----------|
| `homeassistant/home-assistant:2024.11.3` | `registry.cn-hangzhou.aliyuncs.com/homeassistant/home-assistant:2024.11.3` |
| `nodered/node-red:4.0.5` | `registry.cn-hangzhou.aliyuncs.com/3rdparty/nodered/node-red:4.0.5` |
| `eclipse-mosquitto:2.0.20` | `registry.cn-hangzhou.aliyuncs.com/3rdparty/eclipse-mosquitto:2.0.20` |
| `koenkk/zigbee2mqtt:1.41.0` | `registry.cn-hangzhou.aliyuncs.com/3rdparty/koenkk/zigbee2mqtt:1.41.0` |
| `ghcr.io/esphome/esphome:2024.11.1` | `ghcr.m.daocloud.io/esphome/esphome:2024.11.1` |

Or set Docker daemon mirror globally / 或全局设置 Docker 守护进程镜像：

```bash
# Set CN_MODE=true in .env, then run:
./scripts/setup-cn-mirrors.sh
```

## Troubleshooting / 故障排查

### Mosquitto won't start / Mosquitto 无法启动

```bash
# Check logs / 查看日志
docker compose logs mosquitto

# Common issue: passwd file not initialized / 常见问题：密码文件未初始化
./setup-mqtt.sh
docker compose restart mosquitto
```

### Zigbee2MQTT can't find coordinator / Zigbee2MQTT 找不到协调器

```bash
# 1. Check USB device exists / 检查 USB 设备
ls -la /dev/ttyUSB* /dev/ttyACM*

# 2. Check permissions / 检查权限
sudo chmod 666 /dev/ttyUSB0

# 3. Persistent device rule (udev) / 持久化设备规则
echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="zigbee", MODE="0666"' | \
  sudo tee /etc/udev/rules.d/99-zigbee.rules
sudo udevadm control --reload-rules && sudo udevadm trigger

# 4. Use by-id path in .env / 在 .env 中使用 by-id 路径
# ZIGBEE_ADAPTER_PATH=/dev/serial/by-id/usb-xxx
```

### Home Assistant can't connect to MQTT / Home Assistant 连接 MQTT 失败

```bash
# Test MQTT connectivity from inside the container
# 从容器内部测试 MQTT 连接
docker exec homeassistant \
  python3 -c "import paho.mqtt.client as mqtt; c=mqtt.Client(); c.username_pw_set('homeassistant','yourpassword'); c.connect('mosquitto',1883); print('OK')"

# Verify Mosquitto is healthy / 验证 Mosquitto 健康状态
docker compose ps mosquitto
```

### Node-RED "permission denied" errors / Node-RED 权限错误

```bash
# Ensure PUID/PGID match host user / 确保 PUID/PGID 匹配主机用户
id  # Shows your UID and GID

# Fix volume permissions / 修复卷权限
docker compose exec node-red chown -R 1000:1000 /data
```

### ESPHome compilation slow/fails / ESPHome 编译慢或失败

```bash
# Check available disk space / 检查可用磁盘空间
df -h

# ESPHome caches compiled platformio packages in the volume
# Clear cache if needed / 清除缓存
docker compose exec esphome rm -rf /config/.esphome/build
```

### Services can't reach each other / 服务间无法通信

```bash
# Verify both networks exist / 验证两个网络存在
docker network ls | grep -E 'proxy|home-automation'

# Test internal DNS / 测试内部 DNS
docker compose exec homeassistant ping -c 2 mosquitto
docker compose exec node-red ping -c 2 homeassistant
```

## Backup / 备份

```bash
# Stop services first for consistent backup / 先停止服务以保证一致性
docker compose stop

# Backup all volumes / 备份所有卷
for vol in ha-config node-red-data mosquitto-data zigbee2mqtt-data esphome-config; do
  docker run --rm -v "home-automation_${vol}:/source:ro" -v "$(pwd)/backups:/backup" \
    alpine tar czf "/backup/${vol}-$(date +%Y%m%d).tar.gz" -C /source .
done

# Backup config files / 备份配置文件
tar czf "backups/mqtt-config-$(date +%Y%m%d).tar.gz" config/

# Restart / 重新启动
docker compose start
```

## Upgrade / 升级

```bash
# 1. Backup first! / 先备份！
# 2. Edit image versions in docker-compose.yml / 编辑 docker-compose.yml 中的镜像版本
# 3. Pull and recreate / 拉取并重建
docker compose pull
docker compose up -d

# Check logs for errors / 检查日志是否有错误
docker compose logs -f --tail=50
```
