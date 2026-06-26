#!/usr/bin/env bash
# =============================================================================
# Setup CN Mirrors (Docker, Apt, Alpine)
# =============================================================================
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}检测到可能处于中国大陆网络环境。${NC}"
read -p "是否需要配置国内镜像源以加速部署？(y/N): " choice
if [[ ! "$choice" =~ ^[Yy]$ ]]; then
  echo "已取消配置国内镜像源。"
  exit 0
fi

echo -e "${GREEN}==> 配置 Docker 镜像加速...${NC}"

if [ ! -d /etc/docker ]; then
  sudo mkdir -p /etc/docker
fi

DAEMON_JSON="/etc/docker/daemon.json"
TMP_JSON=$(mktemp)

if [ -f "$DAEMON_JSON" ]; then
  sudo cp "$DAEMON_JSON" "$TMP_JSON"
else
  echo "{}" > "$TMP_JSON"
fi

if command -v jq &>/dev/null; then
  jq '. + {"registry-mirrors": ["https://docker.m.daocloud.io", "https://mirror.gcr.io", "https://hub-mirror.c.163.com", "https://mirror.baidubce.com"]}' "$TMP_JSON" > "${TMP_JSON}.tmp"
  mv "${TMP_JSON}.tmp" "$TMP_JSON"
else
  cat > "$TMP_JSON" <<EOF
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://mirror.gcr.io",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
EOF
fi

sudo mv "$TMP_JSON" "$DAEMON_JSON"
sudo systemctl daemon-reload || true
sudo systemctl restart docker || true

echo -e "${GREEN}==> 验证 Docker 镜像配置...${NC}"
if sudo docker pull hello-world > /dev/null; then
  echo -e "${GREEN}[OK] 镜像拉取成功！${NC}"
else
  echo -e "${RED}[FAIL] 镜像拉取失败，请检查网络。${NC}"
fi

echo -e "${GREEN}==> 配置项目脚本中的 apt/apk 镜像加速...${NC}"
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
find "$BASE_DIR/stacks" "$BASE_DIR/scripts" -type f -name "*.sh" -exec sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' {} + || true
find "$BASE_DIR/stacks" "$BASE_DIR/scripts" -type f -name "*.sh" -exec sed -i 's|dl-cdn.alpinelinux.org|mirrors.ustc.edu.cn|g' {} + || true

echo -e "${GREEN}完成国内网络适配配置。${NC}"
