#!/bin/bash
#
# setup-cn-mirrors.sh — 配置 Docker 国内镜像加速
#
# 功能：
# 1. 交互式询问是否位于中国大陆
# 2. 自动备份现有 /etc/docker/daemon.json
# 3. 写入多个稳定镜像源（主/备用）
# 4. 重启 Docker 服务并验证 docker pull hello-world
#
# 用法：
#   sudo bash scripts/setup-cn-mirrors.sh

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    error "请以 root 身份运行此脚本 (sudo bash $0)"
    exit 1
fi

# 交互确认
echo ""
echo "此脚本将配置 Docker 国内镜像加速，以提升镜像拉取速度。"
read -rp "您是否位于中国大陆网络环境？(y/N): " answer
case "${answer,,}" in
    y|yes)
        info "开始配置 Docker 镜像加速..."
        ;;
    *)
        info "跳过 Docker 镜像配置，无需更改。"
        exit 0
        ;;
esac

DOCKER_CONFIG="/etc/docker/daemon.json"
BACKUP_FILE="${DOCKER_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"

# 备份现有配置
if [ -f "$DOCKER_CONFIG" ]; then
    cp "$DOCKER_CONFIG" "$BACKUP_FILE"
    info "已备份当前配置至 $BACKUP_FILE"
fi

# 国内镜像源列表（主/备用）
MIRRORS='[
  "https://docker.m.daocloud.io",
  "https://hub-mirror.c.163.com",
  "https://mirror.gcr.io",
  "https://dockerproxy.com"
]'

# 合并写入 daemon.json
if [ -f "$DOCKER_CONFIG" ]; then
    # 尝试使用 jq 合并（保留原有其他配置）
    if command -v jq &> /dev/null; then
        NEW_CONFIG=$(cat "$DOCKER_CONFIG" | jq --argjson mirrors "$MIRRORS" '.registry_mirrors = $mirrors' 2>/dev/null || echo "")
        if [ -n "$NEW_CONFIG" ]; then
            echo "$NEW_CONFIG" > "$DOCKER_CONFIG"
            info "已合并原有配置并写入镜像源。"
        else
            warn "jq 处理失败，将使用纯镜像配置覆盖。"
            cat > "$DOCKER_CONFIG" <<EOF
{
  "registry-mirrors": $MIRRORS
}
EOF
        fi
    else
        # 尝试使用 python3 的 json 模块合并
        if command -v python3 &> /dev/null; then
            python3 -c "
import json, sys
with open('$DOCKER_CONFIG', 'r') as f:
    config = json.load(f)
config['registry-mirrors'] = json.loads('$MIRRORS')
with open('$DOCKER_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
" && info "已通过 python3 合并配置。" || {
                warn "python3 处理失败，执行覆盖。"
                cat > "$DOCKER_CONFIG" <<EOF
{
  "registry-mirrors": $MIRRORS
}
EOF
            }
        else
            warn "未安装 jq 或 python3，将覆盖现有配置（备份文件仍保留）。"
            cat > "$DOCKER_CONFIG" <<EOF
{
  "registry-mirrors": $MIRRORS
}
EOF
        fi
    fi
else
    # 全新写入
    cat > "$DOCKER_CONFIG" <<EOF
{
  "registry-mirrors": $MIRRORS
}
EOF
fi

info "配置已写入 $DOCKER_CONFIG"

# 重启 Docker 服务
info "正在重启 Docker 服务..."
if command -v systemctl &> /dev/null; then
    systemctl daemon-reload
    systemctl restart docker
elif command -v service &> /dev/null; then
    service docker restart
else
    error "无法找到 systemctl 或 service 命令，请手动重启 Docker。"
    exit 1
fi

# 等待 Docker 就绪
info "等待 Docker 就绪..."
sleep 5

# 验证拉取 hello-world
info "验证镜像加速配置：docker pull hello-world"
if docker pull hello-world; then
    info "Docker 镜像加速配置成功！"
    echo ""
    echo "您可以使用 'docker info' 查看当前 registry mirrors 列表。"
else
    error "镜像拉取失败，请检查网络连接或镜像源可用性。"
    error "您可以恢复备份配置：sudo cp $BACKUP_FILE $DOCKER_CONFIG && sudo systemctl restart docker"
    exit 1
fi
