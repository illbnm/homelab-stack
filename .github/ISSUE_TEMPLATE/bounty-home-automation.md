---
name: 💰 Bounty - Home Automation Stack
about: 实现家庭自动化栈 (Home Assistant, Node-RED, Mosquitto, Zigbee2MQTT)
title: '[BOUNTY $130] Home Automation Stack — 家庭自动化'
labels: bounty, medium
assignees: ''
---

## 赏金金额

**$130 USDT**

## 任务描述

实现完整的智能家居自动化栈，支持 Zigbee 设备接入和可视化流程编排。

## 服务清单

| 服务 | 镜像 | 用途 |
|------|------|------|
| Home Assistant | `ghcr.io/home-assistant/home-assistant:2024.9.3` | 智能家居中枢 |
| Node-RED | `nodered/node-red:4.0.3` | 可视化流程编排 |
| Mosquitto | `eclipse-mosquitto:2.0.19` | MQTT Broker |
| Zigbee2MQTT | `koenkk/zigbee2mqtt:1.40.2` | Zigbee 设备网关 |
| ESPHome | `ghcr.io/esphome/esphome:2024.9.3` | ESP 设备固件管理 |

## 核心要求

### 1. Home Assistant 网络模式

Home Assistant 必须使用 `network_mode: host`，并在 README 中说明原因（mDNS/UPnP 设备发现）。

同时提供 bridge 模式的替代配置（注释掉），说明功能限制。

### 2. Mosquitto 安全配置

```
config/mosquitto/mosquitto.conf:
  -