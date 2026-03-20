#!/usr/bin/env bash
# =============================================================================
# Wait Healthy — Docker Compose 健康检查等待工具
# 等待所有容器健康检查通过，支持超时和详细日志
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# 默认配置
DEFAULT_TIMEOUT=300
DEFAULT_INTERVAL=5
DEFAULT_STACK=""

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "\n${BLUE}${BOLD}==>$NC $*"; }

# 显示进度条
show_progress() {
  local current=$1
  local total=$2
  local width=40
  local percentage=$((current * 100 / total))
  local filled=$((current * width / total))
  local empty=$((width - filled))
  
  printf "\r["
  printf "%${filled}s" | tr ' ' '█'
  printf "%${empty}s" | tr ' ' '░'
  printf "] %3d%% (%ds/%ds)" "$percentage" "$current" "$total"
}

# 获取容器健康状态
get_container_health() {
  local container="$1"
  docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null || echo "unknown"
}

# 获取容器日志 (最后 N 行)
get_container_logs() {
  local container="$1"
  local lines="${2:-20}"
  docker logs --tail "$lines" "$container" 2>&1 || true
}

# 等待单个容器健康
wait_container_healthy() {
  local container="$1"
  local timeout="$2"
  local interval="$3"
  local elapsed=0
  
  while [[ $elapsed -lt $timeout ]]; do
    local health=$(get_container_health "$container")
    
    case "$health" in
      healthy)
        return 0
        ;;
      unhealthy)
        log_error "容器 $container 健康检查失败"
        return 1
        ;;
      starting|none|unknown)
        sleep "$interval"
        elapsed=$((elapsed + interval))
        ;;
    esac
  done
  
  log_error "容器 $container 健康检查超时 (${timeout}s)"
  return 1
}

# 等待整个 stack 健康
wait_stack_healthy() {
  local stack="$1"
  local timeout="$2"
  local interval="$3"
  
  log_step "等待 Stack '$stack' 健康检查通过"
  log_info "超时时间：${timeout}s, 检查间隔：${interval}s"
  
  local start_time=$(date +%s)
  local elapsed=0
  local last_check=0
  
  while [[ $elapsed -lt $timeout ]]; do
    # 获取 stack 的所有容器
    local containers=$(docker compose -p "$stack" ps -q 2>/dev/null || true)
    
    if [[ -z "$containers" ]]; then
      log_warn "未找到 Stack '$stack' 的容器"
      return 1
    fi
    
    local total_containers=$(echo "$containers" | wc -l)
    local healthy_containers=0
    local unhealthy_containers=()
    local starting_containers=()
    
    # 检查每个容器
    while IFS= read -r container; do
      [[ -z "$container" ]] && continue
      
      local health=$(get_container_health "$container")
      local container_name=$(docker inspect --format='{{.Name}}' "$container" | sed 's/^\///')
      
      case "$health" in
        healthy)
          ((healthy_containers++))
          ;;
        unhealthy)
          unhealthy_containers+=("$container_name")
          ;;
        starting|none|unknown)
          starting_containers+=("$container_name")
          ;;
      esac
    done <<< "$containers"
    
    # 显示进度
    show_progress "$healthy_containers" "$total_containers" "$elapsed" "$timeout"
    
    # 检查是否全部健康
    if [[ $healthy_containers -eq $total_containers ]]; then
      echo ""
      log_info "${GREEN}✓ 所有容器健康检查通过!${NC}"
      return 0
    fi
    
    # 检查是否有不健康的容器
    if [[ ${#unhealthy_containers[@]} -gt 0 ]]; then
      echo ""
      log_error "发现 ${#unhealthy_containers[@]} 个不健康容器:"
      for name in "${unhealthy_containers[@]}"; do
        log_error "  - $name"
        log_info "    最后日志:"
        get_container_logs "$name" 10 | sed 's/^/      /'
      done
      return 1
    fi
    
    # 显示正在启动的容器
    if [[ ${#starting_containers[@]} -gt 0 && $((elapsed - last_check)) -ge 10 ]]; then
      echo ""
      log_info "正在启动的容器 (${#starting_containers[@]}):"
      for name in "${starting_containers[@]}"; do
        log_info "  - $name"
      done
      last_check=$elapsed
    fi
    
    sleep "$interval"
    elapsed=$(($(date +%s) - start_time))
  done
  
  echo ""
  log_error "健康检查超时 (${timeout}s)"
  
  # 显示未健康容器详情
  log_warn "未健康容器详情:"
  while IFS= read -r container; do
    [[ -z "$container" ]] && continue
    local health=$(get_container_health "$container")
    local container_name=$(docker inspect --format='{{.Name}}' "$container" | sed 's/^\///')
    
    if [[ "$health" != "healthy" ]]; then
      log_warn "  容器：$container_name"
      log_warn "  状态：$health"
      log_warn "  最后日志:"
      get_container_logs "$container_name" 20 | sed 's/^/    /'
      echo ""
    fi
  done <<< "$containers"
  
  return 1
}

# 列出所有 stack
list_stacks() {
  log_step "可用的 Docker Compose Stacks"
  
  local stacks=$(docker compose ls --format json 2>/dev/null || docker stack ls --format json 2>/dev/null || true)
  
  if [[ -n "$stacks" ]]; then
    echo "$stacks" | jq -r '.[] | "  \(.Name) - \(.Status) (\(.RunningServices) services)"' 2>/dev/null || \
    echo "$stacks" | jq -r '.[] | "  \(.name) - \(.status)"' 2>/dev/null || \
    docker compose ls 2>/dev/null | tail -n +2 | awk '{print "  " $1 " - " $2}'
  else
    log_warn "未找到运行的 Stack"
  fi
}

# 显示帮助
usage() {
  cat <<EOF
用法：$0 [选项]

选项:
  --stack NAME     等待指定 Stack 健康 (必需)
  --timeout SECS   超时时间 (默认：${DEFAULT_TIMEOUT}s)
  --interval SECS  检查间隔 (默认：${DEFAULT_INTERVAL}s)
  --list           列出所有运行的 Stack
  --help           显示帮助信息

示例:
  $0 --stack base --timeout 300          # 等待 base stack 健康，超时 300s
  $0 --stack media --timeout 600         # 等待 media stack 健康，超时 600s
  $0 --list                              # 列出所有 Stack

EOF
  exit 0
}

# 主函数
main() {
  echo -e ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   HomeLab Stack - 健康检查等待工具                       ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
  echo -e ""
  
  # 检查 Docker
  if ! command -v docker &>/dev/null; then
    log_error "Docker 未安装"
    exit 1
  fi
  
  if ! docker info &>/dev/null; then
    log_error "Docker 服务未运行"
    exit 1
  fi
  
  local stack=""
  local timeout="$DEFAULT_TIMEOUT"
  local interval="$DEFAULT_INTERVAL"
  
  # 解析参数
  while [[ $# -gt 0 ]]; do
    case $1 in
      --stack)
        stack="$2"
        shift 2
        ;;
      --timeout)
        timeout="$2"
        shift 2
        ;;
      --interval)
        interval="$2"
        shift 2
        ;;
      --list)
        list_stacks
        exit 0
        ;;
      --help|-h)
        usage
        ;;
      *)
        log_error "未知选项：$1"
        usage
        ;;
    esac
  done
  
  if [[ -z "$stack" ]]; then
    log_error "请指定 --stack 参数"
    usage
  fi
  
  # 等待 stack 健康
  if wait_stack_healthy "$stack" "$timeout" "$interval"; then
    log_info "${GREEN}✓ Stack '$stack' 已就绪!${NC}"
    exit 0
  else
    log_error "${RED}✗ Stack '$stack' 健康检查失败${NC}"
    exit 1
  fi
}

main "$@"
