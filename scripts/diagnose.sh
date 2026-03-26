#!/usr/bin/env bash
# =============================================================================
# diagnose.sh — 一键诊断脚本
# 收集 Docker 版本、系统信息、容器状态、错误日志、网络连通性、配置文件校验
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.."; pwd)"
OUTPUT_DIR="${PROJECT_ROOT}/.diagnose-$(date +%Y%m%d%H%M%S)"
mkdir -p "$OUTPUT_DIR"

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---------------------------------------------------------------------------
# 收集函数
# ---------------------------------------------------------------------------

section() {
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo ""
}

write_report() {
  local section_name="$1"
  local content="$2"
  echo "$content" > "${OUTPUT_DIR}/${section_name}.txt"
}

# ---------------------------------------------------------------------------
# 1. Docker 版本信息
# ---------------------------------------------------------------------------
collect_docker_info() {
  section "Docker 信息"
  echo "报告目录: $OUTPUT_DIR"
  echo ""

  if command -v docker &>/dev/null; then
    echo -e "${BOLD}Docker 版本:${NC}"
    docker version 2>&1 || echo "(无法获取完整版本信息)"

    echo ""
    echo -e "${BOLD}Docker Compose 版本:${NC}"
    if docker compose version &>/dev/null; then
      docker compose version 2>&1
      docker compose version --format json 2>/dev/null | head -20
    elif command -v docker-compose &>/dev/null; then
      docker-compose version 2>&1
    else
      echo "(未找到)"
    fi

    echo ""
    echo -e "${BOLD}Docker 信息:${NC}"
    docker info 2>&1 | head -50

    # 保存完整 docker info
    docker info 2>&1 > "${OUTPUT_DIR}/docker-info.txt"
  else
    echo -e "${RED}Docker 未安装${NC}"
  fi
}

# ---------------------------------------------------------------------------
# 2. 系统信息
# ---------------------------------------------------------------------------
collect_system_info() {
  section "系统信息"

  echo -e "${BOLD}操作系统:${NC}"
  uname -a 2>&1
  cat /etc/os-release 2>/dev/null || echo "(无法获取)"

  echo ""
  echo -e "${BOLD}内核版本:${NC}"
  cat /proc/version 2>/dev/null || uname -r

  echo ""
  echo -e "${BOLD}CPU 信息:${NC}"
  nproc 2>/dev/null && lscpu 2>/dev/null | grep -E "Model name|CPU\(s\)|Thread|Core" | head -5 || echo "(无法获取)"

  echo ""
  echo -e "${BOLD}内存信息:${NC}"
  free -h 2>/dev/null || cat /proc/meminfo 2>/dev/null | head -5

  echo ""
  echo -e "${BOLD}磁盘信息:${NC}"
  df -h 2>/dev/null | grep -E "^/dev|Filesystem"

  echo ""
  echo -e "${BOLD}网络接口:${NC}"
  ip addr 2>/dev/null | grep -E "^[0-9]+:|inet " | head -20 || ifconfig 2>/dev/null | head -20

  # 保存
  {
    uname -a
    echo "---"
    cat /etc/os-release 2>/dev/null
    echo "---"
    free -h 2>/dev/null
    echo "---"
    df -h 2>/dev/null
  } > "${OUTPUT_DIR}/system-info.txt"
}

# ---------------------------------------------------------------------------
# 3. 容器状态
# ---------------------------------------------------------------------------
collect_container_status() {
  section "容器状态"

  echo -e "${BOLD}运行中的容器:${NC}"
  if command -v docker &>/dev/null && docker info &>/dev/null; then
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}" 2>&1 || echo "(无法获取)"

    echo ""
    echo -e "${BOLD}容器健康状态:${NC}"
    docker ps -a --format "{{.Names}}:{{.Status}}" --filter "health=none" 2>/dev/null | grep -v ":running$" || echo "所有容器运行正常"

    echo ""
    echo -e "${BOLD}Docker 网络:${NC}"
    docker network ls 2>&1

    echo ""
    echo -e "${BOLD}Docker 卷:${NC}"
    docker volume ls 2>&1

    # 保存
    docker ps -a > "${OUTPUT_DIR}/containers.txt"
    docker network ls > "${OUTPUT_DIR}/networks.txt"
  else
    echo "(Docker 不可用)"
  fi
}

# ---------------------------------------------------------------------------
# 4. 错误日志
# ---------------------------------------------------------------------------
collect_error_logs() {
  section "错误日志"

  if command -v docker &>/dev/null && docker info &>/dev/null; then
    echo -e "${BOLD}最近 24 小时内的错误日志:${NC}"

    # 检查所有容器最近 24 小时的日志
    local containers
    containers=$(docker ps -aq 2>/dev/null)

    if [[ -n "$containers" ]]; then
      local has_errors=false
      for cid in $containers; do
        local cname
        cname=$(docker inspect --format='{{.Name}}' "$cid" 2>/dev/null | sed 's/^\///')
        local logs
        logs=$(docker logs --tail 200 --since "24h" "$cid" 2>&1 | grep -iE "error|fatal|exception|critical|failed" || true)

        if [[ -n "$logs" ]]; then
          has_errors=true
          echo ""
          echo -e "  ${RED}容器: $cname${NC}"
          echo "  ───────────────────────────────────────────"
          echo "$logs" | head -20 | sed 's/^/    /'
          echo "  ───────────────────────────────────────────"
        fi
      done

      if [[ "$has_errors" == "false" ]]; then
        echo "  ${GREEN}未发现错误日志${NC}"
      fi
    else
      echo "  (无运行中的容器)"
    fi

    # 保存完整日志
    for cid in $containers; do
      local cname
      cname=$(docker inspect --format='{{.Name}}' "$cid" 2>/dev/null | sed 's/^\///')
      docker logs --tail 100 "$cid" 2>&1 > "${OUTPUT_DIR}/log-${cname}.txt" 2>/dev/null || true
    done
  else
    echo "(Docker 不可用)"
  fi

  echo ""
  echo -e "${BOLD}系统日志 (dmesg, 最后 50 行):${NC}"
  dmesg 2>/dev/null | tail -50 | grep -iE "error|failed|warning" || dmesg 2>/dev/null | tail -10
}

# ---------------------------------------------------------------------------
# 5. 网络连通性
# ---------------------------------------------------------------------------
collect_network_connectivity() {
  section "网络连通性"

  echo -e "${BOLD}网络连通性检测:${NC}"
  if [[ -x "$SCRIPT_DIR/check-connectivity.sh" ]]; then
    bash "$SCRIPT_DIR/check-connectivity.sh" --quick 2>&1
  else
    echo "(check-connectivity.sh 不存在，跳过)"
  fi

  echo ""
  echo -e "${BOLD}当前 DNS 配置:${NC}"
  cat /etc/resolv.conf 2>/dev/null || echo "(无法获取)"

  echo ""
  echo -e "${BOLD}路由表:${NC}"
  ip route 2>/dev/null || route -n 2>/dev/null || echo "(无法获取)"

  echo ""
  echo -e "${BOLD}端口监听状态:${NC}"
  ss -tlnp 2>/dev/null | head -30 || netstat -tlnp 2>/dev/null | head -30 || echo "(无法获取)"

  echo ""
  echo -e "${BOLD}代理配置:${NC}"
  echo "HTTP_PROXY: ${HTTP_PROXY:-未设置}"
  echo "HTTPS_PROXY: ${HTTPS_PROXY:-未设置}"
  echo "NO_PROXY: ${NO_PROXY:-未设置}"
  echo "http_proxy: ${http_proxy:-未设置}"
  echo "https_proxy: ${https_proxy:-未设置}"
}

# ---------------------------------------------------------------------------
# 6. 配置文件校验
# ---------------------------------------------------------------------------
collect_config_validation() {
  section "配置文件校验"

  echo -e "${BOLD}.env 文件检查:${NC}"
  local env_file="${PROJECT_ROOT}/.env"
  if [[ -f "$env_file" ]]; then
    echo "  ✓ .env 文件存在"

    # 检查关键变量
    local required_vars=(
      "DOMAIN"
      "ACME_EMAIL"
      "TRAEFIK_DASHBOARD_USER"
      "TRAEFIK_DASHBOARD_PASSWORD_HASH"
      "TZ"
    )

    for var in "${required_vars[@]}"; do
      local val
      val=$(grep -E "^${var}=" "$env_file" | cut -d= -f2- | tr -d '"\x27' || echo "")
      if [[ -n "$val" && "$val" != "yourdomain.com" && "$val" != "you@example.com" ]]; then
        echo "  ✓ $var 已配置"
      else
        echo -e "  ${RED}✗${NC} $var 未配置或仍为占位符"
      fi
    done
  else
    echo -e "  ${RED}✗${NC} .env 文件不存在"
  fi

  echo ""
  echo -e "${BOLD}Docker daemon.json 检查:${NC}"
  local daemon_json="/etc/docker/daemon.json"
  if [[ -f "$daemon_json" ]]; then
    echo "  ✓ daemon.json 存在"
    cat "$daemon_json"
  else
    echo "  (daemon.json 不存在，使用默认配置)"
  fi

  echo ""
  echo -e "${BOLD}ACME JSON 检查:${NC}"
  local acme_path="${PROJECT_ROOT}/config/traefik/acme.json"
  if [[ -f "$acme_path" ]]; then
    local perms
    perms=$(stat -c '%a' "$acme_path" 2>/dev/null || stat -f '%A' "$acme_path" 2>/dev/null || echo "")
    if [[ "$perms" == "600" ]]; then
      echo "  ✓ acme.json 存在且权限正确 (600)"
    else
      echo -e "  ${YELLOW}!${NC} acme.json 权限: $perms (应为 600)"
    fi
  else
    echo -e "  ${YELLOW}!${NC} acme.json 不存在"
  fi

  echo ""
  echo -e "${BOLD}docker-compose 文件语法检查:${NC}"
  if command -v docker &>/dev/null && docker compose version &>/dev/null; then
    local compose_files
    mapfile -t compose_files < <(find "${PROJECT_ROOT}/stacks" -name "docker-compose*.yml" -type f 2>/dev/null)

    for cf in "${compose_files[@]}"; do
      if docker compose -f "$cf" config --quiet 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $(basename "$cf")"
      else
        echo -e "  ${RED}✗${NC} $(basename "$cf") - 语法错误"
      fi
    done
  else
    echo "  (docker compose 不可用，跳过)"
  fi

  echo ""
  echo -e "${BOLD}目录权限检查:${NC}"
  for dir in config data stacks scripts; do
    local path="${PROJECT_ROOT}/${dir}"
    if [[ -d "$path" ]]; then
      local perms
      perms=$(stat -c '%a' "$path" 2>/dev/null || echo "")
      echo "  $dir: $perms"
    fi
  done
}

# ---------------------------------------------------------------------------
# 7. 资源使用情况
# ---------------------------------------------------------------------------
collect_resource_usage() {
  section "资源使用情况"

  echo -e "${BOLD}Docker 资源使用:${NC}"
  if command -v docker &>/dev/null && docker info &>/dev/null; then
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>&1 | head -20 || echo "(无法获取)"
  else
    echo "(Docker 不可用)"
  fi

  echo ""
  echo -e "${BOLD}磁盘空间详情:${NC}"
  df -h 2>/dev/null

  echo ""
  echo -e "${BOLD}Docker 磁盘使用:${NC}"
  if command -v docker &>/dev/null; then
    docker system df 2>&1 || echo "(无法获取)"
  fi
}

# ---------------------------------------------------------------------------
# 生成摘要报告
# ---------------------------------------------------------------------------
generate_summary() {
  section "诊断摘要"

  local total_space
  total_space=$(df -BG / 2>/dev/null | awk 'NR==2 {gsub(/G/,"",$4); print $4}' || echo "?")

  local docker_ok="否"
  if command -v docker &>/dev/null && docker info &>/dev/null; then
    docker_ok="是"
  fi

  local compose_ok="否"
  if command -v docker &>/dev/null && docker compose version &>/dev/null; then
    compose_ok="是"
  fi

  local env_ok="否"
  if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    env_ok="是"
  fi

  local container_count=0
  if command -v docker &>/dev/null; then
    container_count=$(docker ps -aq 2>/dev/null | wc -l)
  fi

  cat <<EOF
诊断时间: $(date '+%Y-%m-%d %H:%M:%S')
报告目录: $OUTPUT_DIR

关键检查项:
  Docker 安装: $docker_ok
  Docker Compose v2: $compose_ok
  .env 文件: $env_ok
  运行中容器: $container_count 个
  可用磁盘空间: ${total_space}GB

详细报告文件:
$(ls -1 "$OUTPUT_DIR"/*.txt 2>/dev/null | sed 's|.*/||' | sed 's/^/  - /')

下一步建议:
  1. 查看上述报告文件了解详细信息
  2. 如有问题，运行: ./scripts/check-connectivity.sh 进行网络检测
  3. 如需重新初始化: rm -rf data/* && ./install.sh
EOF
}

# ---------------------------------------------------------------------------
# 主函数
# ---------------------------------------------------------------------------

main() {
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║                                                          ║${NC}"
  echo -e "${BLUE}║              HomeLab Stack 一键诊断工具                  ║${NC}"
  echo -e "${BLUE}║                                                          ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""

  log_info "诊断报告将保存到: $OUTPUT_DIR"
  echo ""

  collect_system_info
  collect_docker_info
  collect_container_status
  collect_error_logs
  collect_network_connectivity
  collect_config_validation
  collect_resource_usage
  generate_summary

  echo ""
  log_info "诊断完成！"
  echo ""
}

main "$@"
