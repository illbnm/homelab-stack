#!/bin/bash
# =============================================================================
# Home Automation Stack — Mosquitto 认证配置脚本
# HomeLab Stack
# =============================================================================

set -e

STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../stacks/home-automation" && pwd)"
cd "$STACK_DIR"

echo "🏠 Home Automation Stack — Mosquitto 认证配置"
echo "================================================"

# 检查 mosquitto_passwd 是否可用
if ! command -v mosquitto_passwd &> /dev/null; then
    echo "⚠️  mosquitto_passwd 未安装，尝试安装..."
    apt update && apt install -y mosquitto-clients
fi

# 生成密码（使用环境变量或默认值）
HA_PASS="${HA_MQTT_PASSWORD:-homeassistant}"
NR_PASS="${NODERED_MQTT_PASSWORD:-nodered}"
Z2M_PASS="${ZIGBEE2MQTT_MQTT_PASSWORD:-zigbee2mqtt}"
ESP_PASS="${ESPHOME_MQTT_PASSWORD:-esphome}"

echo ""
echo "📝 创建用户账号..."
echo ""

# 创建用户和密码
echo "  创建 ha 用户..."
mosquitto_passwd -c -b passwords ha "$HA_PASS" 2>/dev/null || mosquitto_passwd -b passwords ha "$HA_PASS"

echo "  创建 nodered 用户..."
mosquitto_passwd -b passwords nodered "$NR_PASS"

echo "  创建 zigbee2mqtt 用户..."
mosquitto_passwd -b passwords zigbee2mqtt "$Z2M_PASS"

echo "  创建 esphome 用户..."
mosquitto_passwd -b passwords esphome "$ESP_PASS"

echo ""
echo "✅ Mosquitto 密码文件已生成: $STACK_DIR/passwords"
echo ""
echo "📋 用户凭据（请妥善保管，或更新 .env 中的密码）:"
echo "   ha           : $HA_PASS"
echo "   nodered      : $NR_PASS"
echo "   zigbee2mqtt  : $Z2M_PASS"
echo "   esphome      : $ESP_PASS"
echo ""
echo "⚠️  请记得更新 .env 文件中的相应密码变量"
echo ""
echo "🚀 重启 Mosquitto 使配置生效:"
echo "   docker compose restart mosquitto"
