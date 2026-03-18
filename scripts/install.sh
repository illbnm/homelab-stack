#!/usr/bin/env bash
# install.sh — 一键安装 Docker 和 homelab-stack

set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.. && pwd)"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${GREEN}=== homelab-stack 一键安装 ===${NC}"

# 1. 检查操作系统
OS="$(uname -s)"
ARCH="$(uname -m)"
echo "OS: $OS, Arch: $ARCH"

# 2. 安装 Docker
if ! command -v docker &>/dev/null; then
  echo -e "${YELLOW}Docker 未安装，开始安装...${NC}"
  if [[ "$OS" == "Linux" ]]; then
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✅ Docker 安装完成${NC}"
  elif [[ "$OS" == "Darwin" ]]; then
    echo "请从 https://docs.docker.com/desktop/install/mac-install/ 安装 Docker Desktop"
    exit 1
  fi
else
  echo -e "${GREEN}✅ Docker 已安装${NC}"
fi

# 3. 安装 Docker Compose (如果缺少)
if ! docker compose version &>/dev/null; then
  echo -e "${YELLOW}Docker Compose 插件未安装，安装中...${NC}"
  mkdir -p ~/.docker/cli-plugins
  curl -SL https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m) -o ~/.docker/cli-plugins/docker-compose
  chmod +x ~/.docker/cli-plugins/docker-compose
  echo -e "${GREEN}✅ Docker Compose 安装完成${NC}"
else
  echo -e "${GREEN}✅ Docker Compose 已安装${NC}"
fi

# 4. 克隆仓库
if [[ ! -d "$BASE_DIR/.git" ]]; then
  echo -e "${YELLOW}克隆 homelab-stack 仓库...${NC}"
  git clone https://github.com/aerospaziale/homelab-stack.git "$BASE_DIR"
  cd "$BASE_DIR"
  git remote set-url origin https://github.com/illbnm/homelab-stack.git
else
  echo -e "${GREEN}✅ 仓库已存在${NC}"
fi

# 5. 配置环境变量
if [[ ! -f "$BASE_DIR/.env" ]]; then
  echo -e "${YELLOW}创建 .env 配置文件...${NC}"
  cat > "$BASE_DIR/.env" <<'EOF'
# 域名 (必须)
DOMAIN=homelab.example.com

# 时区
TZ=Asia/Shanghai

# 密码 (请修改!)
POSTGRES_PASSWORD=change-me
REDIS_PASSWORD=change-me
ADGUARD_PASSWORD=change-me
WIREGUARD_PASSWORD=change-me
HA_DB_PASSWORD=change-me
HA_AUTH_TOKEN=
ZIGBEE2MQTT_PASSWORD=change-me
MOSQUITTO_PASSWORD=change-me
ESPHOME_API_PASSWORD=change-me

# Cloudflare (DDNS 需要)
CLOUDFLARE_EMAIL=
CLOUDFLARE_API_TOKEN=
EOF
  echo -e "${GREEN}✅ .env 已创建，请编辑并设置真实密码${NC}"
else
  echo -e "${GREEN}✅ .env 已存在${NC}"
fi

# 6. 启动 Base Stack (Traefik 等)
echo -e "${YELLOW}启动 Base Stack (Traefik, Portainer)...${NC}"
cd "$BASE_DIR"
docker compose -f stacks/base/docker-compose.yml up -d

# 7. 等待 Traefik 就绪
echo -e "${YELLOW}等待 Traefik 就绪 (60s)...${NC}"
sleep 60

# 8. 可选: 应用中国镜像加速 (如果在中国)
read -p "是否应用中国大陆镜像加速配置? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  bash scripts/setup-cn-mirrors.sh
fi

# 9. 完成
echo -e "${GREEN}=== 安装完成！===${NC}"
echo "1. 编辑 .env 文件，设置所有密码"
echo "2. 确保域名解析到服务器 IP"
echo "3. 启动所需 Stack: docker compose -f stacks/<stack>/docker-compose.yml up -d"
echo "4. 查看日志: docker compose -f stacks/<stack>/docker-compose.yml logs -f"
echo ""
echo "访问:"
echo "- Traefik Dashboard: https://traefik.${DOMAIN}"
echo "- Portainer: https://portainer.${DOMAIN}"
echo ""
echo "下一步: 选择需要的 Stack 启动"