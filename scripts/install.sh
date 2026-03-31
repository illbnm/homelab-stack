#!/bin/bash
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 脚本开始
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}HomeLab Stack 安装脚本${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# 检查系统兼容性
check_system() {
  local os_type=""
  
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    os_type=$ID
  fi
  
  case "$os_type" in
    ubuntu|debian)
      echo -e "${GREEN}✓ 检测到 Debian/Ubuntu 系统${NC}"
      return 0
      ;;
    centos|rhel)
      echo -e "${GREEN}✓ 检测到 CentOS/RHEL 系统${NC}"
      return 0
      ;;
    arch)
      echo -e "${GREEN}✓ 检测到 Arch Linux 系统${NC}"
      return 0
      ;;
    *)
      echo -e "${YELLOW}⚠️  不确定的系统类型: $os_type${NC}"
      return 0
      ;;
  esac
}

# 检查内存
check_memory() {
  local available_memory=$(free -g | awk 'NR==2 {print $7}')
  
  echo "检查系统内存... (${available_memory}GB 可用)"
  
  if [[ $available_memory -lt 2 ]]; then
    echo -e "${YELLOW}⚠️  警告: 系统内存少于 2GB，可能影响运行效能${NC}"
  else
    echo -e "${GREEN}✓ 系统内存充足${NC}"
  fi
}

# 检查磁盘空间
check_disk_space() {
  local available_space=$(df / | awk 'NR==2 {print $4}')
  local available_gb=$((available_space / 1048576))
  
  echo "检查磁盘空间... (${available_gb}GB 可用)"
  
  if [[ $available_gb -lt 5 ]]; then
    echo -e "${RED}✗ 错误: 磁盘空间少于 5GB，无法继续安装${NC}"
    return 1
  elif [[ $available_gb -lt 20 ]]; then
    echo -e "${YELLOW}⚠️  警告: 磁盘空间少于 20GB，建议清理空间${NC}"
  else
    echo -e "${GREEN}✓ 磁盘空间充足${NC}"
  fi
}

# 检查并安装 Docker
check_docker() {
  echo ""
  echo "检查 Docker 安装状态..."
  
  if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}未检测到 Docker，开始安装...${NC}"
    
    # 获取系统类型
    if [[ -f /etc/os-release ]]; then
      . /etc/os-release
      os_type=$ID
    fi
    
    case "$os_type" in
      ubuntu|debian)
        apt-get update
        apt-get install -y curl
        curl -fsSL https://get.docker.com -o get-docker.sh
        bash get-docker.sh
        rm get-docker.sh
        ;;
      centos|rhel)
        yum install -y curl
        curl -fsSL https://get.docker.com -o get-docker.sh
        bash get-docker.sh
        rm get-docker.sh
        ;;
      arch)
        pacman -Sy docker --noconfirm
        systemctl enable docker
        systemctl start docker
        ;;
      *)
        echo -e "${RED}不支持的系统类型${NC}"
        return 1
        ;;
    esac
    
    echo -e "${GREEN}✓ Docker 安装完成${NC}"
  else
    echo -e "${GREEN}✓ Docker 已安装${NC}"
  fi
}

# 检查 Docker Compose 版本
check_docker_compose() {
  echo "检查 Docker Compose..."
  
  if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}未检测到 docker-compose，尝试使用 docker compose...${NC}"
    
    if ! docker compose version &> /dev/null; then
      echo -e "${YELLOW}安装 Docker Compose v2...${NC}"
      
      DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
      mkdir -p $DOCKER_CONFIG/cli-plugins
      curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
      chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
      
      echo -e "${GREEN}✓ Docker Compose v2 安装完成${NC}"
    fi
  else
    local compose_version=$(docker-compose --version | grep -oP '\d+\.\d+\.\d+' | head -1)
    local major_version=${compose_version%%.*}
    
    if [[ $major_version -lt 2 ]]; then
      echo -e "${YELLOW}⚠️  检测到 Docker Compose v1，建议升级到 v2${NC}"
      echo "升级命令: sudo apt-get install -y docker-compose"
    else
      echo -e "${GREEN}✓ Docker Compose v2 已安装${NC}"
    fi
  fi
}

# 检查非 root 用户
check_and_add_docker_group() {
  if [[ $EUID -ne 0 ]]; then
    echo ""
    echo "检查 Docker 权限..."
    
    if ! groups | grep -q docker; then
      echo -e "${YELLOW}当前用户不在 docker 组，尝试添加...${NC}"
      sudo usermod -aG docker $(whoami)
      echo -e "${GREEN}✓ 已添加用户到 docker 组，需要重新登录生效${NC}"
    else
      echo -e "${GREEN}✓ 用户已在 docker 组${NC}"
    fi
  fi
}

# 检查端口冲突
check_port_conflicts() {
  echo ""
  echo "检查端口占用..."
  
  local ports=(53 80 443 3000 8080 8443 8081)
  local conflicts=0
  
  for port in "${ports[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
      echo -e "${YELLOW}⚠️  端口 $port 已被占用${NC}"
      ((conflicts++))
    fi
  done
  
  if [[ $conflicts -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  检测到 $conflicts 个端口冲突，可能影响服务部署${NC}"
  else
    echo -e "${GREEN}✓ 主要端口未被占用${NC}"
  fi
}

# 网络检测
check_network() {
  echo ""
  echo "检查网络连通性..."
  
  if [[ -x ./scripts/check-connectivity.sh ]]; then
    ./scripts/check-connectivity.sh
  else
    echo -e "${YELLOW}⚠️  网络检查脚本不存在，跳过${NC}"
  fi
}

# 创建必要目录
create_directories() {
  echo ""
  echo "创建必要目录..."
  
  mkdir -p config data logs
  echo -e "${GREEN}✓ 目录创建完成${NC}"
}

# 主流程
main() {
  check_system
  check_memory
  
  if ! check_disk_space; then
    exit 1
  fi
  
  echo ""
  
  # 检查是否为 root
  if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}某些检查需要 root 权限${NC}"
    check_and_add_docker_group
  else
    check_docker
    check_docker_compose
  fi
  
  check_port_conflicts
  check_network
  create_directories
  
  echo ""
  echo -e "${GREEN}================================================${NC}"
  echo -e "${GREEN}✓ 环境检查完成，准备就绪${NC}"
  echo -e "${GREEN}================================================${NC}"
  echo ""
  echo "下一步: docker-compose up -d"
}

main "$@"
