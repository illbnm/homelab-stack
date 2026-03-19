#!/usr/bin/env bash
# entrypoint-setup.sh — Robustness Stack 容器入口

set -euo pipefail

BASE_DIR="/workspace"
SCRIPTS_DIR="/scripts"
CONFIG_DIR="/config"

echo "=== Robustness Stack Setup Entrypoint ==="
echo "时间: $(date)"
echo

# 1. 检查 Docker 连接
echo "[1/5] 检查 Docker 连接..."
if docker version &>/dev/null; then
  echo "✅ Docker 可达"
else
  echo "❌ Docker 不可达，检查 /var/run/docker.sock"
  exit 1
fi

# 2. 检查网络连通性
echo "[2/5] 网络连通性检测..."
if [[ -x "$SCRIPTS_DIR/check-connectivity.sh" ]]; then
  "$SCRIPTS_DIR/check-connectivity.sh" || echo "⚠️  部分目标不可达，可使用镜像加速"
else
  echo "⚠️  check-connectivity.sh 不存在"
fi

# 3. 镜像加速 (可选)
echo "[3/5] 镜像加速配置..."
if [[ -f "$CONFIG_DIR/cn-mirrors.yml" ]]; then
  echo "找到配置文件: $CONFIG_DIR/cn-mirrors.yml"
  echo "手动运行: $SCRIPTS_DIR/localize-images.sh"
else
  echo "⚠️  未找到 cn-mirrors.yml"
fi

# 4. 诊断信息收集
echo "[4/5] 系统诊断..."
if [[ -x "$SCRIPTS_DIR/diagnose.sh" ]]; then
  "$SCRIPTS_DIR/diagnose.sh" || true
else
  echo "⚠️  diagnose.sh 不存在"
fi

# 5. 完成
echo "[5/5] 初始化完成"
echo
echo "可用命令:"
echo "  $SCRIPTS_DIR/check-connectivity.sh  # 连通性检测"
echo "  $SCRIPTS_DIR/diagnose.sh            # 系统诊断"
echo "  $SCRIPTS_DIR/localize-images.sh     # 应用镜像加速"
echo "  $SCRIPTS_DIR/install.sh             # 本地一键安装"
echo
echo "建议下一步:"
echo "1. 编辑 .env 文件，设置所有密码"
echo "2. 运行: $SCRIPTS_DIR/install.sh"
echo "3. 启动所需 Stack"

# 保持容器运行 (如果需要)
if [[ "${KEEP_RUNNING:-false}" == "true" ]]; then
  echo "保持容器运行..."
  tail -f /dev/null
fi