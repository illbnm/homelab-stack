# Home Automation Stack

智能家居自动化堆栈，包含 Home Assistant、Node-RED、ESPHome、Zigbee2MQTT 和 Mosquitto MQTT broker。

## 服务

| 服务 | 端口 | 说明 |
|------|------|------|
| Home Assistant | 8123 | 智能家居核心平台 |
| Node-RED | 1880 | 流程自动化 |
| ESPHome | 6052 | ESP8266/ESP32 设备管理 |
| Zigbee2MQTT | 8080 | Zigbee 设备桥接 |
| Mosquitto | 1883 | MQTT 消息代理 |

## 快速开始

### 1. 配置环境变量

```bash
# 复制环境配置
cp .env.example .env

# 编辑并设置密码
nano .env
```

必须配置以下变量：
- `MQTT_PASSWORD` - MQTT 连接密码
- `ESPHOME_API_PASSWORD` - ESPHome API 密码
- `ESPHOME_OTA_PASSWORD` - ESPHome OTA 密码
- `ZIGBEE_SERIAL` - Zigbee USB 适配器路径

### 2. 生成 MQTT 密码

```bash
# 进入目录
cd stacks/home-automation

# 生成密码文件 (交互式)
docker run --rm -it -v $(pwd):/data eclipse-mosquitto mosquitto_passwd -c /data/mosquitto-passwords homeassistant

# 如果需要添加更多用户
docker run --rm -it -v $(pwd):/data eclipse-mosquitto mosquitto_passwd /data/mosquitto-passwords esphome
docker run --rm -it -v $(pwd):/data eclipse-mosquitto mosquitto_passwd /data/mosquitto-passwords zigbee2mqtt
docker run --rm -it -v $(pwd):/data eclipse-mosquitto mosquitto_passwd /data/mosquitto-passwords nodered
```

### 3. 启动堆栈

```bash
cd stacks/home-automation
docker compose up -d
```

### 4. 访问服务

- Home Assistant: http://localhost:8123
- Node-RED: http://localhost:1880
- ESPHome Dashboard: http://localhost:6052
- Zigbee2MQTT: http://localhost:8080

## 配置详情

### Home Assistant

使用 `network_mode: host` 模式，直接访问主机网络。

```yaml
network_mode: host
privileged: true  # 需要访问硬件
```

### Mosquitto MQTT

带密码认证和 ACL 控制的 MQTT broker。

**默认用户：**
- `homeassistant` - Home Assistant 使用
- `esphome` - ESPHome 设备
- `zigbee2mqtt` - Zigbee 网桥
- `nodered` - Node-RED 流程

**ACL 规则：**
- 每个用户只能读写自己的主题
- `homeassistant` 可访问所有 `homeassistant/#` 主题
- `esphome` 可访问 `esphome/#` 和 `homeassistant/#`
- `zigbee2mqtt` 可访问 `zigbee2mqtt/#`

### Zigbee2MQTT

Zigbee 设备到 MQTT 的桥接服务。

**配置选项：**
- `ZIGBEE_SERIAL` - USB 适配器路径
  - `/dev/ttyUSB0` - 常见 USB dongle
  - `/dev/ttyACM0` - 常见 Arduino 设备
  - `/dev/serial/by-id/usb-...` - 固定路径

**支持的适配器：**
- CC2531, CC2530
- CC2652R, CC2652P, CC2652RB
- Sonoff Zigbee 3.0 USB Dongle Plus
- Electrolama zig-a-zig-ah (zzh)

### ESPHome

ESP8266/ESP32 设备的固件管理和远程配置。

**功能：**
- OTA (Over-The-Air) 更新
- REST API
- Web Dashboard
- MQTT 集成
- 捕获门户 (首次配网)

**示例设备配置：**

```yaml
esphome:
  name: my_sensor
  platform: ESP8266

sensor:
  - platform: dht
    pin: D2
    temperature:
      name: "Living Room Temperature"
    humidity:
      name: "Living Room Humidity"
```

## 故障排除

### 查看日志

```bash
# 所有服务
docker compose logs -f

# 特定服务
docker compose logs -f homeassistant
docker compose logs -f mosquitto
docker compose logs -f zigbee2mqtt
```

### MQTT 连接问题

```bash
# 测试 MQTT 连接
docker exec mosquitto mosquitto_sub -t "test" -v -u homeassistant -P "your_password"
```

### Zigbee 设备问题

1. 检查 USB 适配器是否被识别：
   ```bash
   ls -la /dev/ttyUSB*
   ```

2. 在 docker-compose.yml 中添加设备映射：
   ```yaml
   devices:
     - /dev/ttyUSB0:/dev/ttyUSB0
   ```

### ESPHome 配网失败

1. 设备首次启动会创建 AP
2. 连接 `ESP Fallback` WiFi
3. 密码为配置的 `wifi_password`
4. 打开 http://192.168.4.1 配置 WiFi

## 安全注意事项

1. **更改所有默认密码**
2. **不要提交密码文件到 Git**
3. **使用强密码** (至少 16 位随机字符)
4. **限制 ACL 权限** - 只授予必要的 topic 访问权限

## 数据持久化

| 容器 | 卷 | 数据 |
|------|-----|------|
| homeassistant | ha-config | 配置、日志、数据库 |
| node-red | node-red-data | 流程、配置 |
| mosquitto | mosquitto-data, mosquitto-logs | 消息持久化、日志 |
| zigbee2mqtt | zigbee2mqtt-data | 设备数据库、日志 |
| esphome | esphome-config | 设备配置 |

## 扩展

### 添加更多 Zigbee 设备

1. 打开 Zigbee2MQTT 前端
2. 点击 "Permit Join"
3. 重置设备 (通常是电源开关几次)
4. 等待设备出现在列表中

### 添加 ESPHome 设备

1. 打开 ESPHome Dashboard
2. 点击 "+" 创建新设备
3. 选择设备类型和配置
4. 点击 "Upload" 编译并刷写

## 相关链接

- [Home Assistant](https://www.home-assistant.io/)
- [Node-RED](https://nodered.org/)
- [ESPHome](https://esphome.io/)
- [Zigbee2MQTT](https://www.zigbee2mqtt.io/)
- [Mosquitto](https://mosquitto.org/)