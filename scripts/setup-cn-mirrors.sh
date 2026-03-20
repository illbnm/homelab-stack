#!/usr/bin/env bash
# =============================================================================
# Setup CN Mirrors — 国内网络环境 Docker 镜像加速配置
# 自动配置 Docker daemon.json 使用国内镜像源
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==>$NC $*"; }

# Docker 镜像源列表 (主 + 备用)
MIRRORS=(
  "https://gcr.m.daocloud.io"
  "https://docker.m.daocloud.io"
  "https://hub-mirror.c.163.com"
  "https://mirror.baidubce.com"
  "https://registry.cn-hangzhou.aliyuncs.com"
)

# 检测是否在中国大陆
check_cn_network() {
  log_step "检测网络环境"
  
  # 测试 GitHub 访问速度
  local start_time=$(date +%s%N)
  if curl -sf --connect-timeout 3 --max-time 5 "https://github.com" &>/dev/null; then
    local end_time=$(date +%s%N)
    local latency=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $latency -gt 500 ]]; then
      log_warn "GitHub 访问延迟 ${latency}ms (>500ms)，建议开启镜像加速"
      return 0  # 可能是国内网络
    else
      log_info "GitHub 访问延迟 ${latency}ms，网络状况良好"
    fi
  else
    log_warn "GitHub 访问超时，可能在国内网络环境"
    return 0  # 可能是国内网络
  fi
  
  # 测试 gcr.io 访问
  if ! curl -sf --connect-timeout 3 --max-time 5 "https://gcr.io" &>/dev/null; then
    log_warn "gcr.io 无法访问，需要使用国内镜像"
    return 0  # 需要国内镜像
  fi
  
  # 测试 ghcr.io 访问
  if ! curl -sf --connect-timeout 3 --max-time 5 "https://ghcr.io" &>/dev/null; then
    log_warn "ghcr.io 无法访问，需要使用国内镜像"
    return 0  # 需要国内镜像
  fi
  
  log_info "网络环境检测完成，未检测到明显的国内网络特征"
  return 1  # 可能不需要国内镜像
}

# 检测 Docker 是否已安装
check_docker() {
  if ! command -v docker &>/dev/null; then
    log_error "Docker 未安装，请先安装 Docker"
    exit 1
  fi
  
  if ! docker info &>/dev/null; then
    log_error "Docker 服务未运行，请启动 Docker 服务"
    exit 1
  fi
  
  log_info "Docker 已安装并运行正常"
}

# 备份现有配置
backup_config() {
  local config_file="/etc/docker/daemon.json"
  local backup_file="/etc/docker/daemon.json.backup.$(date +%Y%m%d%H%M%S)"
  
  if [[ -f "$config_file" ]]; then
    log_info "备份现有配置: $backup_file"
    sudo cp "$config_file" "$backup_file"
  fi
}

# 配置 Docker daemon.json
configure_docker_daemon() {
  local config_file="/etc/docker/daemon.json"
  
  log_step "配置 Docker daemon.json"
  
  # 构建镜像源配置
  local mirrors_json=""
  for i in "${!MIRRORS[@]}"; do
    if [[ $i -gt 0 ]]; then
      mirrors_json+=","
    fi
    mirrors_json+="\"${MIRRORS[$i]}\""
  done
  
  # 创建或更新 daemon.json
  if [[ -f "$config_file" ]]; then
    # 已存在，合并配置
    log_info "更新现有 daemon.json"
    
    # 读取现有配置并添加 registry-mirrors
    local temp_file=$(mktemp)
    if command -v jq &>/dev/null; then
      # 使用 jq 合并
      jq --argjson mirrors "[$mirrors_json]" \
        '.["registry-mirrors"] = $mirrors' \
        "$config_file" > "$temp_file"
    else
      # 不使用 jq，简单处理
      log_warn "jq 未安装，使用简单配置覆盖"
      cat > "$temp_file" <<EOF
{
  "registry-mirrors": [$mirrors_json],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF
    fi
    
    sudo mv "$temp_file" "$config_file"
  else
    # 创建新配置
    log_info "创建新的 daemon.json"
    sudo mkdir -p /etc/docker
    
    cat | sudo tee "$config_file" > /dev/null <<EOF
{
  "registry-mirrors": [$mirrors_json],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF
  fi
  
  log_info "daemon.json 配置完成"
  cat "$config_file" | sudo cat
}

# 重启 Docker 服务
restart_docker() {
  log_step "重启 Docker 服务"
  
  if systemctl is-active --quiet docker; then
    sudo systemctl restart docker
    log_info "Docker 服务已重启"
  elif service docker status &>/dev/null; then
    sudo service docker restart
    log_info "Docker 服务已重启 (service)"
  else
    log_warn "无法识别 Docker 服务管理方式，请手动重启 Docker"
    return 1
  fi
  
  # 等待 Docker 服务就绪
  sleep 3
  if docker info &>/dev/null; then
    log_info "Docker 服务已就绪"
  else
    log_error "Docker 服务重启失败"
    return 1
  fi
}

# 验证配置
verify_config() {
  log_step "验证镜像加速配置"
  
  log_info "测试 docker pull hello-world..."
  if docker pull hello-world &>/dev/null; then
    log_info "✓ 镜像拉取测试成功"
    docker rmi hello-world &>/dev/null || true
  else
    log_error "✗ 镜像拉取测试失败"
    log_warn "请检查网络连接或尝试其他镜像源"
    return 1
  fi
  
  # 显示当前配置的镜像源
  log_info "当前配置的镜像源:"
  docker info 2>/dev/null | grep -A 10 "Registry Mirrors" || true
}

# 恢复原始配置
restore_config() {
  log_step "恢复原始 Docker 配置"
  
  local config_file="/etc/docker/daemon.json"
  local backup_files=($(ls -t /etc/docker/daemon.json.backup.* 2>/dev/null || true))
  
  if [[ ${#backup_files[@]} -eq 0 ]]; then
    log_warn "未找到备份文件"
    return 1
  fi
  
  local latest_backup="${backup_files[0]}"
  log_info "恢复备份: $latest_backup"
  
  sudo mv "$latest_backup" "$config_file"
  
  log_info "重启 Docker 服务..."
  restart_docker
  
  log_info "配置已恢复"
}

# 显示帮助
usage() {
  cat <<EOF
用法: $0 [选项]

选项:
  --auto      自动检测并配置 (推荐)
  --force     强制配置，跳过检测
  --restore   恢复原始配置
  --check     仅检查网络环境，不修改配置
  --list      列出所有可用镜像源
  --help      显示此帮助信息

示例:
  $0 --auto              # 自动检测并配置
  $0 --force             # 强制配置
  $0 --restore           # 恢复原始配置
  $0 --check             # 检查网络环境

EOF
  exit 0
}

# 主函数
main() {
  echo -e ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   HomeLab Stack - Docker 国内镜像加速配置工具           ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
  echo -e ""
  
  # 检查 root 权限
  if [[ $EUID -ne 0 ]]; then
    log_error "此脚本需要 root 权限，请使用 sudo 运行"
    exit 1
  fi
  
  # 检查 Docker
  check_docker
  
  case "${1:-}" in
    --auto)
      if check_cn_network; then
        log_info "检测到国内网络环境，开始配置镜像加速..."
        backup_config
        configure_docker_daemon
        restart_docker
        verify_config
        log_info "${GREEN}✓ 配置完成！${NC}"
      else
        log_info "未检测到国内网络环境，跳过配置"
        log_warn "如需强制配置，请使用 --force 选项"
      fi
      ;;
    
    --force)
      log_warn "强制配置模式"
      backup_config
      configure_docker_daemon
      restart_docker
      verify_config
      log_info "${GREEN}✓ 配置完成！${NC}"
      ;;
    
    --restore)
      restore_config
      ;;
    
    --check)
      if check_cn_network; then
        log_info "建议配置国内镜像加速"
      else
        log_info "网络环境良好，无需配置"
      fi
      ;;
    
    --list)
      log_info "可用镜像源列表:"
      for i in "${!MIRRORS[@]}"; do
        echo "  $((i+1)). ${MIRRORS[$i]}"
      done
      ;;
    
    --help|-h)
      usage
      ;;
    
    *)
      # 交互式模式
      echo "请选择操作:"
      echo "  1) 自动检测并配置 (推荐)"
      echo "  2) 强制配置"
      echo "  3) 恢复原始配置"
      echo "  4) 检查网络环境"
      echo "  5) 列出镜像源"
      echo "  6) 退出"
      echo ""
      read -p "请输入选项 (1-6): " choice
      
      case $choice in
        1)
          if check_cn_network; then
            backup_config
            configure_docker_daemon
            restart_docker
            verify_config
            log_info "${GREEN}✓ 配置完成！${NC}"
          else
            log_info "未检测到国内网络环境"
            read -p "是否继续配置？(y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
              backup_config
              configure_docker_daemon
              restart_docker
              verify_config
              log_info "${GREEN}✓ 配置完成！${NC}"
            fi
          fi
          ;;
        2)
          backup_config
          configure_docker_daemon
          restart_docker
          verify_config
          log_info "${GREEN}✓ 配置完成！${NC}"
          ;;
        3)
          restore_config
          ;;
        4)
          check_cn_network
          ;;
        5)
          for i in "${!MIRRORS[@]}"; do
            echo "  $((i+1)). ${MIRRORS[$i]}"
          done
          ;;
        6)
          log_info "退出"
          exit 0
          ;;
        *)
          log_error "无效选项"
          exit 1
          ;;
      esac
      ;;
  esac
}

main "$@"
