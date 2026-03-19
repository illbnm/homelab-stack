#!/usr/bin/env bash
# =============================================================================
# Setup CN Mirrors — Docker 国内镜像加速配置脚本
# 交互式配置 Docker daemon.json 使用国内镜像源
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[setup-cn-mirrors]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[setup-cn-mirrors]${NC} $*" >&2; }
log_error() { echo -e "${RED}[setup-cn-mirrors]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[setup-cn-mirrors]${NC} $*"; }

# Docker 镜像源列表（主→备）
MIRRORS=(
  "mirror.gcr.io"
  "docker.m.daocloud.io"
  "hub-mirror.c.163.com"
  "mirror.baidubce.com"
)

DAEMON_JSON="/etc/docker/daemon.json"

# 检查是否在中国大陆网络环境
check_cn_network() {
  log_step "检测网络环境..."
  
  # 测试 GitHub 连接速度
  local start_time=$(date +%s%N)
  if curl -sf --connect-timeout 3 --max-time 5 "https://github.com" &>/dev/null; then
    local end_time=$(date +%s%N)
    local latency=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $latency -gt 500 ]]; then
      log_warn "GitHub 延迟 ${latency}ms，建议开启镜像加速"
      return 0  # 建议开启
    else
      log_info "GitHub 延迟 ${latency}ms，网络状况良好"
    fi
  else
    log_warn "GitHub 连接超时，强烈建议开启镜像加速"
    return 0  # 建议开启
  fi
  
  # 测试 Docker Hub
  if ! curl -sf --connect-timeout 3 --max-time 5 "https://hub.docker.com" &>/dev/null; then
    log_warn "Docker Hub 连接失败，需要镜像加速"
    return 0
  fi
  
  return 1  # 不需要开启
}

# 备份现有配置
backup_config() {
  if [[ -f "$DAEMON_JSON" ]]; then
    local backup="${DAEMON_JSON}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$DAEMON_JSON" "$backup"
    log_info "已备份现有配置：$backup"
  fi
}

# 写入 daemon.json 配置
write_daemon_config() {
  log_step "配置 Docker 镜像加速..."
  
  # 创建 /etc/docker 目录（如果不存在）
  sudo mkdir -p /etc/docker
  
  # 构建 JSON 配置
  local mirror_json="["
  local first=true
  for mirror in "${MIRRORS[@]}"; do
    if [[ "$first" == true ]]; then
      mirror_json+="\"https://$mirror\""
      first=false
    else
      mirror_json+=",\"https://$mirror\""
    fi
  done
  mirror_json+="]"
  
  # 写入配置文件
  sudo tee "$DAEMON_JSON" > /dev/null << EOF
{
  "registry-mirrors": $mirror_json,
  "live-restore": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF
  
  log_info "已写入配置文件：$DAEMON_JSON"
}

# 重启 Docker 服务
restart_docker() {
  log_step "重启 Docker 服务..."
  
  if sudo systemctl restart docker; then
    log_info "Docker 服务重启成功"
    sleep 2
  else
    log_error "Docker 服务重启失败"
    return 1
  fi
}

# 验证配置
verify_config() {
  log_step "验证镜像加速配置..."
  
  # 检查 daemon.json 是否生效
  local mirrors
  mirrors=$(sudo docker info --format '{{json .RegistryConfig.Mirrors}}' 2>/dev/null || echo "[]")
  
  if [[ "$mirrors" != "[]" ]]; then
    log_info "镜像加速已启用：$mirrors"
  else
    log_warn "镜像加速配置可能未生效"
  fi
  
  # 测试拉取 hello-world
  log_step "测试拉取 hello-world 镜像..."
  if sudo docker pull hello-world &>/dev/null; then
    log_info "✓ hello-world 拉取成功，镜像加速工作正常"
    return 0
  else
    log_error "✗ hello-world 拉取失败"
    return 1
  fi
}

# 显示使用说明
show_usage() {
  echo ""
  echo "=============================================="
  echo "  Docker 国内镜像加速配置完成！"
  echo "=============================================="
  echo ""
  echo "已配置的镜像源："
  for i in "${!MIRRORS[@]}"; do
    echo "  $((i+1)). ${MIRRORS[$i]}"
  done
  echo ""
  echo "使用方法："
  echo "  docker pull <image>  # 自动使用镜像加速"
  echo ""
  echo "如需恢复原始配置："
  echo "  sudo rm $DAEMON_JSON"
  echo "  sudo systemctl restart docker"
  echo ""
}

# 主函数
main() {
  echo ""
  echo "=============================================="
  echo "  Docker 国内镜像加速配置工具"
  echo "=============================================="
  echo ""
  
  # 检查是否以 root 运行
  if [[ $EUID -ne 0 ]]; then
    log_warn "此脚本需要 root 权限，将使用 sudo 执行"
  fi
  
  # 检查 Docker 是否安装
  if ! command -v docker &>/dev/null; then
    log_error "Docker 未安装，请先安装 Docker"
    exit 1
  fi
  
  # 检测网络环境
  local need_mirrors=false
  if check_cn_network; then
    need_mirrors=true
  fi
  
  # 交互式询问
  if [[ "$need_mirrors" == true ]]; then
    echo ""
    read -p "检测到您可能在中国大陆网络环境，是否配置 Docker 镜像加速？[Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
      log_info "开始配置镜像加速..."
    else
      log_info "已跳过配置"
      exit 0
    fi
  else
    echo ""
    read -p "是否配置 Docker 镜像加速？[y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      log_info "开始配置镜像加速..."
    else
      log_info "已跳过配置"
      exit 0
    fi
  fi
  
  # 备份现有配置
  backup_config
  
  # 写入配置
  write_daemon_config
  
  # 重启 Docker
  restart_docker
  
  # 验证配置
  if verify_config; then
    show_usage
    log_info "配置完成！"
    exit 0
  else
    log_error "验证失败，请检查配置"
    exit 1
  fi
}

main "$@"
