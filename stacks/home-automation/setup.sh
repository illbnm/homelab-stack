#!/bin/bash
# ============================================================
# Home Automation Stack - 快速设置脚本
# ============================================================

set -e

echo "🏠 Home Automation Stack - 设置脚本"
echo ""

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

echo "✓ Docker 已安装"

# 检查 Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose 未安装，请先安装"
    exit 1
fi

echo "✓ Docker Compose 已安装"
echo ""

# 创建配置目录
echo "📁 创建配置目录..."
mkdir -p config/mosquitto/data config/mosquitto/log
mkdir -p config/homeassistant
mkdir -p config/nodered
mkdir -p config/zigbee2mqtt
mkdir -p config/esphome

# 复制 .env 文件
if [ ! -f .env ]; then
    echo "📝 创建 .env 文件..."
    cp .env.example .env
    echo "⚠️  请编辑 .env 文件，修改默认密码和配置"
fi

# 配置 Mosquitto
echo ""
echo "🔐 配置 Mosquitto 认证..."
echo "请输入 Home Assistant 用户密码:"
read -s HA_PASSWORD

docker run --rm -v $(pwd)/config/mosquitto:/mosquitto eclipse-mosquitto:2.0.19 \
    mosquitto_passwd -b /mosquitto/passwordfile homeassistant "$HA_PASSWORD"

echo "✓ Home Assistant 用户已创建"

echo ""
echo "请输入 Node-RED 用户密码:"
read -s NODERED_PASSWORD

docker run --rm -v $(pwd)/config/mosquitto:/mosquitto eclipse-mosquitto:2.0.19 \
    mosquitto_passwd -b /mosquitto/passwordfile nodered "$NODERED_PASSWORD"

echo "✓ Node-RED 用户已创建"

# 生成 Zigbee2MQTT 网络密钥
echo ""
echo "🔑 生成 Zigbee2MQTT 网络密钥..."
NETWORK_KEY=$(openssl rand -h 16 | sed 's/://g')
sed -i.bak "s/GENERATE/$NETWORK_KEY/" config/zigbee2mqtt/configuration.yaml
echo "✓ 网络密钥已生成"

# 生成 ESPHome 密钥
echo ""
echo "🔑 生成 ESPHome 密钥..."
API_KEY=$(openssl rand -h 32 | tr -d '\n')
OTA_PASSWORD=$(openssl rand -h 16 | tr -d '\n')

sed -i.bak "s/your_api_key_here/$API_KEY/" config/esphome/secrets.yaml
sed -i.bak "s/your_ota_password_here/$OTA_PASSWORD/" config/esphome/secrets.yaml

echo "✓ ESPHome 密钥已生成"

echo ""
echo "✅ 设置完成！"
echo ""
echo "📋 下一步："
echo "  1. 编辑 .env 文件，修改 WiFi SSID 和密码"
echo "  2. 运行: docker-compose up -d"
echo "  3. 访问 Home Assistant: http://localhost:8123"
echo "  4. 访问 Node-RED: http://localhost:1880"
echo "  5. 访问 Zigbee2MQTT: http://localhost:8080"
echo ""
echo "📚 详细文档请查看 README.md"
