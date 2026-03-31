# 🚀 快速入门指南

5 分钟快速启动您的智能家居自动化栈。

## 📋 前置要求

- Docker 20.10+
- Docker Compose 2.0+
- USB 端口（用于 Zigbee 协调器）
- 至少 2GB 可用内存

## ⚡ 快速启动（3 步）

### 1️⃣ 克隆并设置

```bash
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack
make setup
```

### 2️⃣ 配置 WiFi

编辑 `config/esphome/secrets.yaml`：

```yaml
wifi_ssid: "YourWiFiName"
wifi_password: "YourWiFiPassword"
```

### 3️⃣ 启动

```bash
make up
```

## 🎉 完成！

现在访问：
- **Home Assistant**: http://localhost:8123
- **Node-RED**: http://localhost:1880
- **Zigbee2MQTT**: http://localhost:8080

## 📱 添加第一个 Zigbee 设备

1. 打开 Zigbee2MQTT 界面 (http://localhost:8080)
2. 点击 "Permit Join"
3. 将 Zigbee 设备设置为配对模式
4. 设备将自动出现在 Home Assistant 中

## 🔧 常用命令

```bash
# 查看日志
make logs

# 重启服务
make restart

# 停止服务
make down

# 更新到最新版本
make update

# 备份配置
make backup
```

## 🆘 遇到问题？

1. **端口冲突**: 修改 `docker-compose.yml` 中的端口映射
2. **USB 权限**: 运行 `sudo chmod 666 /dev/ttyUSB0`
3. **内存不足**: 增加虚拟内存或减少服务数量

详细文档请查看 [README.md](README.md)

## 📚 下一步

1. [配置 Home Assistant](https://www.home-assistant.io/getting-started/)
2. [创建 Node-RED 流程](https://nodered.org/docs/tutorials/)
3. [添加更多 Zigbee 设备](https://www.zigbee2mqtt.io/guide/)
4. [刷写 ESP 设备](https://esphome.io/guides/getting_started_command_line.html)

---

**祝您享受智能家居之旅！** 🏠✨
