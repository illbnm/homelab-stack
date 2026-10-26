#!/usr/bin/env bash
# 生成 Mosquitto 密码文件（config/mosquitto/passwd）。
# 用法：先 cp stacks/home-automation/.env.example stacks/home-automation/.env 并设置 MQTT_PASSWORD，
#       然后执行本脚本，最后 docker compose up -d。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_DIR="$ROOT_DIR/stacks/home-automation"
CONFIG_DIR="$ROOT_DIR/config/mosquitto"
PASSWD_FILE="$CONFIG_DIR/passwd"

if [ -f "$STACK_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$STACK_DIR/.env"
  set +a
fi

MQTT_USER="${MQTT_USER:-mqtt}"
MQTT_PASSWORD="${MQTT_PASSWORD:-}"

if [ -z "$MQTT_PASSWORD" ]; then
  echo "错误：请先在 stacks/home-automation/.env 中设置 MQTT_PASSWORD" >&2
  exit 1
fi

mkdir -p "$CONFIG_DIR"
touch "$PASSWD_FILE"

docker run --rm \
  -v "$CONFIG_DIR:/mosquitto/config" \
  eclipse-mosquitto:2.0.19 \
  mosquitto_passwd -b -c /mosquitto/config/passwd "$MQTT_USER" "$MQTT_PASSWORD"

chmod 600 "$PASSWD_FILE"
echo "已写入 $PASSWD_FILE（用户：$MQTT_USER）"
