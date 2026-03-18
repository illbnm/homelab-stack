# Zigbee 设备配对指南

HomeLab Stack — Home Automation

## 前置条件

1. Zigbee2MQTT 容器已正常运行
2. Zigbee 协调器（Coordinator）已连接到主机 USB
3. Mosquitto MQTT Broker 运行中

## 硬件兼容列表

| 协调器 | 芯片 | 推荐度 | 备注 |
|--------|------|--------|------|
| Sonoff Zigbee 3.0 USB Dongle Plus | CC2652P | ⭐⭐⭐⭐⭐ | 性价比最高 |
| ConBee II | R21 | ⭐⭐⭐⭐ | 稳定可靠 |
| CC2531 | CC2531 | ⭐⭐ | 已过时，不推荐 |
| SkyConnect | EFR32 | ⭐⭐⭐⭐ | Home Assistant 官方 |

## 配对步骤

### 1. 确认协调器连接

```bash
# 检查设备是否被识别
ls -la /dev/ttyUSB* /dev/ttyACM*

# 查看 Zigbee2MQTT 日志
docker logs -f zigbee2mqtt
```

看到类似输出表示正常：
```
Zigbee2MQTT:info  MQTT connected
Zigbee2MQTT:info  Zigbee started
```

### 2. 进入配对模式

**方式一：通过 Web UI**
1. 访问 `https://zigbee.${DOMAIN}`
2. 点击左上角 **"允许设备加入（Allow joins）"**
3. 倒计时 250 秒内完成配对

**方式二：通过 MQTT 发布**
```bash
mosquitto_pub -h localhost -t "zigbee2mqtt/bridge/request/permit_join" -m '{"value": true}'
```

### 3. 设备进入配对模式

常见设备操作：

| 设备类型 | 进入配对方式 |
|----------|-------------|
| 灯泡 | 开关 3-5 次（快闪表示配对中） |
| 开关/按钮 | 长按配对按钮 5 秒 |
| 传感器 | 按配对按钮或拔电池重插 |
| 插座 | 长按按钮 5 秒直到快闪 |
| 门磁 | 按按钮或拔电池重插 |

### 4. 确认配对成功

配对成功后 Zigbee2MQTT 日志会显示：
```
Device '0x00158d000xxxxx' joined
Interview completed
```

Web UI 中会显示新设备。

### 5. 设备命名和分组

1. 在 Zigbee2MQTT Web UI 点击设备
2. 修改 **Friendly name** 为易识别的名称（如 `living_room_light`）
3. 分配到对应的 **Group**

## 支持的品牌/设备

Zigbee2MQTT 支持 3000+ 设备，包括：

- **照明**：IKEA TRÅDFRI, Philips Hue, Yeelight, Aqara
- **传感器**：Aqara, Sonoff, Tuya, MiJia
- **开关**：Aqara, Sonoff, IKEA, Tuya
- **插座**：Aqara, Sonoff, IKEA, BlitzWolf
- **窗帘**：Aqara, IKEA, Tuya

完整列表：https://www.zigbee2mqtt.io/supported-devices/

## 常见问题

### Q: 设备无法配对？
1. 确认协调器固件已更新到最新版本
2. 将设备靠近协调器（<2米）再试
3. 检查设备是否已与其他网络配对（需先重置）
4. 查看日志 `docker logs zigbee2mqtt`

### Q: 设备频繁离线？
1. 增加 Zigbee 中继器/路由器设备（插座可充当中继）
2. 远离 WiFi 路由器（2.4GHz 干扰）
3. 检查协调器天线位置

### Q: 如何重置设备？
- 每个设备重置方式不同，参考：
  - https://zigbee.blakadder.com 找到对应设备的重置方法
