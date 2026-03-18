#!/usr/bin/env bash
# =============================================================================
# setup-cn-mirrors.sh — Docker 镜像加速配置（中国大陆）
#
# Usage:
#   sudo ./scripts/setup-cn-mirrors.sh
# =============================================================================

set -euo pipefail

DAEMON_JSON="/etc/docker/daemon.json"
DAEMON_BACKUP="/etc/docker/daemon.json.bak"

log()  { echo "[cn-mirrors] $*"; }
ok()   { echo "[cn-mirrors] ✅ $*"; }
fail() { echo "[cn-mirrors] ❌ $*"; }

# ── Check if in China ────────────────────────────────────────────────────────

echo ""
echo "=============================================="
echo "  Docker 镜像加速配置"
echo "=============================================="
echo ""

read -p "是否在中国大陆使用？(y/N): " -r
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
  log "跳过镜像加速配置"
  exit 0
fi

# ── Backup ───────────────────────────────────────────────────────────────────

if [[ -f "$DAEMON_JSON" ]]; then
  cp "$DAEMON_JSON" "$DAEMON_BACKUP"
  ok "已备份 ${DAEMON_JSON}"
fi

# ── Write config ─────────────────────────────────────────────────────────────

log "写入镜像加速配置..."

cat > "$DAEMON_JSON" <<'EOF'
{
  "registry-mirrors": [
    "https://mirror.gcr.io",
    "https://docker.m.daocloud.io",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

ok "配置已写入 ${DAEMON_JSON}"

# ── Restart Docker ───────────────────────────────────────────────────────────

log "重启 Docker..."
systemctl restart docker
ok "Docker 已重启"

# ── Verify ───────────────────────────────────────────────────────────────────

log "验证配置..."
if docker pull hello-world >/dev/null 2>&1; then
  ok "docker pull hello-world 成功！镜像加速已生效"
  docker rmi hello-world >/dev/null 2>&1 || true
else
  fail "docker pull 失败，请检查网络连接"
  exit 1
fi

echo ""
echo "=============================================="
echo "  镜像加速配置完成！"
echo "  主镜像源: mirror.gcr.io"
echo "  备用: daocloud.io / 163.com / baidubce.com"
echo "=============================================="
