#!/usr/bin/env bash
# 生成 / 更新 Mosquitto 密码文件
# 用法：
#   ./scripts/setup-mosquitto.sh                  # 用 .env 中的 MQTT_USER/MQTT_PASSWORD 重建
#   ./scripts/setup-mosquitto.sh <user> <pass>    # 追加或覆盖指定用户
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_DIR="$ROOT_DIR/stacks/home-automation"
PASSWD_DIR="$STACK_DIR/data/mosquitto"
IMAGE="eclipse-mosquitto:2.0.19"

if [[ -f "$STACK_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a; source "$STACK_DIR/.env"; set +a
fi

USER_NAME="${1:-${MQTT_USER:-mqtt}}"
USER_PASS="${2:-${MQTT_PASSWORD:-changeme}}"

mkdir -p "$PASSWD_DIR/data" "$PASSWD_DIR/log"

if [[ -f "$PASSWD_DIR/passwd" && $# -eq 0 ]]; then
  echo "[setup-mosquitto] 重建密码文件（原有用户将被清空）"
  rm -f "$PASSWD_DIR/passwd"
fi

if [[ -f "$PASSWD_DIR/passwd" ]]; then
  docker run --rm -v "$PASSWD_DIR:/passwd" "$IMAGE" \
    mosquitto_passwd -b /passwd/passwd "$USER_NAME" "$USER_PASS"
else
  docker run --rm -v "$PASSWD_DIR:/passwd" "$IMAGE" \
    mosquitto_passwd -c -b /passwd/passwd "$USER_NAME" "$USER_PASS"
fi

# 容器内以 mosquitto 用户运行，需保证可读
chmod 644 "$PASSWD_DIR/passwd"
chmod 755 "$PASSWD_DIR"

echo "[setup-mosquitto] 已写入 $PASSWD_DIR/passwd（用户：$USER_NAME）"
