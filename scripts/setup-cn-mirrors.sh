#!/usr/bin/env bash
# =============================================================================
# Docker CN Mirror Setup
# Configures Docker daemon to use Chinese mirror registries
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_FILE="/etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)"

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  log_error "此脚本需要 root 权限运行"
  echo "请使用: sudo $0"
  exit 1
fi

# Interactive prompt
echo -e "\n${BOLD}${BLUE}=== Docker 镜像加速配置 ===${NC}\n"
read -p "是否在中国大陆部署? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  log_info "已取消配置"
  exit 0
fi

# Backup existing config
if [[ -f "$DAEMON_JSON" ]]; then
  log_info "备份现有配置到: $BACKUP_FILE"
  cp "$DAEMON_JSON" "$BACKUP_FILE"
fi

# Create mirror configuration
log_info "生成镜像加速配置..."

mkdir -p /etc/docker

cat > "$DAEMON_JSON" <<'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://mirror.ccs.tencentyun.com",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  }
}
EOF

log_info "配置已写入 $DAEMON_JSON"

# Restart Docker daemon
log_info "重启 Docker 服务..."
if systemctl restart docker; then
  log_info "Docker 服务重启成功"
else
  log_error "Docker 服务重启失败"
  exit 1
fi

# Verify configuration
sleep 3
log_info "验证配置..."

if docker info 2>/dev/null | grep -A 5 "Registry Mirrors" | grep -q "mirror"; then
  log_info "镜像加速配置生效"
  echo -e "\n配置的镜像源:"
  docker info 2>/dev/null | grep -A 10 "Registry Mirrors" | grep -E "^\s+https://"
else
  log_warn "镜像加速配置可能未生效，请检查 Docker 日志"
fi

# Test pull
log_info "测试拉取镜像..."
if timeout 60 docker pull hello-world >/dev/null 2>&1; then
  log_info "镜像拉取测试成功 ✓"
  docker rmi hello-world >/dev/null 2>&1 || true
else
  log_warn "镜像拉取测试失败，请检查网络连接"
fi

echo -e "\n${GREEN}${BOLD}✓ Docker 镜像加速配置完成${NC}\n"
echo "配置文件: $DAEMON_JSON"
echo "备份文件: $BACKUP_FILE"
echo ""
echo "恢复原配置:"
echo "  sudo mv $BACKUP_FILE $DAEMON_JSON && sudo systemctl restart docker"
