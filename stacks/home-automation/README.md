# Home Automation Stack

智能家居自动化完整解决方案，支持 Zigbee 设备接入和可视化流程编排。

## 服务概览

| 服务 | 镜像 | 端口 | 说明 |
|------|------|------|------|
| Home Assistant | `ghcr.io/home-assistant/home-assistant:2024.9.3` | 8123 | 智能家居中枢 |
| Node-RED | `nodered/node-red:4.0.3` | 1880 | 可视化流程编排 |
| Mosquitto | `eclipse-mosquitto:2.0.19` | 1883/9001 | MQTT Broker |
| Zigbee2MQTT | `koenkk/zigbee2mqtt:1.40.2` | 8080 | Zigbee 设备网关 |
| ESPHome | `ghcr.io/esphome/esphome:2024.9.3` | 6052 | ESP 设备固件管理 |

## 网络架构

```
┌─────────────────┐     ┌──────────────────┐
│   Zigbee设备    │     │    ESP设备       │
└────────┬────────┘     └────────┬─────────┘
         │                        │
         ▼                        ▼
┌─────────────────────────────────────────┐
│           Zigbee2MQTT / ESPHome         │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│              Mosquitto (MQTT)            │
└────────────────┬────────────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
┌───────────────┐  ┌───────────────┐
│Home Assistant │  │   Node-RED    │
│  (HA)         │  │  (自动化流程)  │
└───────────────┘  └───────────────┘
```

## Home Assistant 网络模式说明

### 为什么使用 Host 网络模式？

Home Assistant **必须**使用 `network_mode: host` 原因如下：

1. **mDNS 发现**: Home Assistant 需要通过 mDNS (multicast DNS) 发现局域网中的设备，例如：
   - Apple HomeKit 设备
   - Chromecast/Audio
   - Hue Bridge
   - ESPHome 设备

2. **UPnP/SSDP 发现**: 用于发现：
   - 网络电视
   - 游戏主机
   - 网络存储设备

3. **部分集成需要**: 某些集成必须在 host 网络模式下工作：
   - Z-Wave JS (需要访问 `/dev/serial/by-id`)
   - Zigbee USB 适配器直接访问
   - 广播/多播功能

### 替代方案 (Bridge 模式)

如果必须使用 bridge 网络模式，某些功能将受限：

- ❌ mDNS 设备发现将失效
- ❌ UPnP/SSDP 设备发现失效
- ❌ 部分集成无法使用
- ⚠️ 需要手动配置设备 IP

替代配置在 docker-compose.yml 中已提供（注释掉）。

## 快速开始

### 1. 启动栈

```bash
# 使用 stack-manager 启动
./scripts/stack-manager.sh start home-automation

# 或直接使用 docker-compose
cd stacks/home-automation
docker-compose up -d
```

### 2. 首次配置

#### Home Assistant
- 访问 `https://ha.${DOMAIN}`
- 首次启动需要 5-10 分钟初始化
- 创建管理员账户

#### Node-RED
- 访问 `https://nodered.${DOMAIN}`
- 默认无需认证（生产环境建议配置）

#### Zigbee2MQTT
- 访问 `https://z2m.${DOMAIN}`
- 首次使用需要配置 Zigbee 适配器
- 支持自动配对模式

#### ESPHome
- 访问 `https://esphome.${DOMAIN}`
- 添加第一个设备后会自动发现

### 3. 配置 MQTT 集成

在 Home Assistant 中：
1. 设置 → 设备与服务 → 添加集成
2. 搜索 "MQTT"
3. 配置 broker: `mosquitto`
4. 端口: `1883`

## Zigbee2MQTT 配置

### 首次配对 Zigbee 设备

1. 访问 Zigbee2MQTT 界面
2. 点击 "Permit join" 按钮
3. 按照设备说明进入配对模式
4. 设备会自动出现在列表中

### 支持的设备类型

- 智能灯泡 (开关、亮度、色温、RGB)
- 传感器 (温度、湿度、运动、门窗)
- 开关/按钮
- 插座
- 窗帘电机
- 门锁

## ESPHome 配置

### 添加新设备

1. 在 ESPHome 界面点击 "+" 新建设备
2. 选择设备类型并输入 WiFi 凭证
3. 编译并下载固件
4. 通过 OTA 或 USB 烧录到 ESP 设备

### 常用配置示例

```yaml
esphome:
  name: my_sensor
  friendly_name: My Temperature Sensor

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password

sensor:
  - platform: dht
    pin: GPIO4
    temperature:
      name: "Temperature"
    humidity:
      name: "Humidity"
```

## 集成示例

### Home Assistant ← MQTT ← Node-RED

**Node-RED 流程**:
```json
[
    {
        "id": "motion-trigger",
        "type": "mqtt in",
        "topic": "zigbee2mqtt/motion_sensor",
        "outputs": 1
    },
    {
        "id": "ha-api",
        "type": "api-call-service",
        "domain": "light",
        "service": "turn_on",
        "data": {"brightness": 255}
    }
]
```

### ESPHome → MQTT → Home Assistant

```yaml
mqtt:
  broker: mosquitto
  on_message:
    - topic: homeassistant/switch/garage/command
      then:
        - switch.toggle: garage_door
```

## 环境变量

在 `.env` 文件中设置：

```bash
# Home Automation
TZ=Asia/Shanghai
```

## 数据持久化

| Volume | 用途 |
|--------|------|
| `ha-config` | Home Assistant 配置和历史数据 |
| `node-red-data` | Node-RED 流程和配置 |
| `mosquitto-data` | MQTT 消息持久化 |
| `zigbee2mqtt-data` | Zigbee 设备数据库 |
| `esphome-config` | ESPHome 设备配置 |

## 健康检查

```bash
# 检查所有服务状态
docker ps | grep -E 'homeassistant|node-red|mosquitto|zigbee2mqtt|esphome'

# 查看日志
docker logs homeassistant
docker logs node-red
docker logs mosquitto
docker logs zigbee2mqtt
docker logs esphome
```

## 安全建议

1. **Mosquitto**: 生产环境建议启用认证
2. **Node-RED**: 配置用户名密码
3. **Zigbee2MQTT**: 设置 API token
4. **ESPHome**: 配置 API 密码
5. **Firewall**: 只开放必要的端口

## 故障排除

### Home Assistant 无法发现设备

- 确认使用 `network_mode: host`
- 检查防火墙允许 mDNS (UDP 5353)

### MQTT 连接失败

- 检查 Mosquitto 是否运行: `docker logs mosquitto`
- 验证端口: `telnet mosquitto 1883`

### Zigbee 设备配对失败

- 确保 Zigbee 适配器正确挂载
- 检查设备兼容性列表
- 远离干扰源（WiFi 路由器、微波炉）

## 相关文档

- [Home Assistant 文档](https://www.home-assistant.io/docs/)
- [Node-RED 文档](https://nodered.org/docs/)
- [Zigbee2MQTT 文档](https://www.zigbee2mqtt.io/)
- [ESPHome 文档](https://esphome.io/)