#!/usr/bin/env bash
# =============================================================================
# wait-healthy.sh — Docker Compose 健康等待
# 等待所有容器健康检查通过，超时后打印未健康容器的最后日志
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# 默认超时（秒）
DEFAULT_TIMEOUT=300
CHECK_INTERVAL=5
LOG_LINES=50

# ---------------------------------------------------------------------------
# 辅助函数
# ---------------------------------------------------------------------------

usage() {
  cat <<'EOF'
用法: wait-healthy.sh [compose_file] [选项]

等待 Docker Compose 堆栈中所有容器通过健康检查。

参数:
  compose_file    docker-compose 文件路径（默认: docker-compose.yml）

选项:
  -t, --timeout SECONDS  超时时间（默认: 300秒）
  -i, --interval SECONDS 检查间隔（默认: 5秒）
  -l, --log-lines LINES  超时后打印的日志行数（默认: 50）
  -s, --stack NAME       指定堆栈名称（与 compose_file 二选一）
  -f, --follow           实时打印健康检查进度
  -h, --help             显示帮助

示例:
  ./wait-healthy.sh                        # 等待当前目录的 compose 堆栈
  ./wait-healthy.sh docker-compose.yml     # 指定 compose 文件
  ./wait-healthy.sh -t 600 -f               # 600秒超时，实时输出
  ./wait-healthy.sh -s monitoring          # 等待 monitoring 堆栈
EOF
}

get_compose_file() {
  local stack="${1:-}"
  local compose_file=""

  if [[ -n "$stack" ]]; then
    local stack_dir="./stacks/${stack}"
    if [[ -f "${stack_dir}/docker-compose.local.yml" ]]; then
      compose_file="${stack_dir}/docker-compose.local.yml"
    elif [[ -f "${stack_dir}/docker-compose.yml" ]]; then
      compose_file="${stack_dir}/docker-compose.yml"
    else
      log_error "堆栈目录不存在或无 compose 文件: $stack_dir"
      exit 1
    fi
  elif [[ -f "docker-compose.yml" ]]; then
    compose_file="docker-compose.yml"
  elif [[ -f "docker-compose.local.yml" ]]; then
    compose_file="docker-compose.local.yml"
  fi

  echo "$compose_file"
}

get_container_health() {
  local container="$1"
  docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none"
}

get_container_status() {
  local container="$1"
  docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown"
}

get_container_name() {
  local container="$1"
  docker inspect --format='{{.Name}}' "$container" 2>/dev/null | sed 's/^\///'
}

# ---------------------------------------------------------------------------
# 核心逻辑
# ---------------------------------------------------------------------------

wait_for_healthy() {
  local compose_file="$1"
  local timeout="$2"
  local interval="$3"
  local log_lines="$4"
  local follow="${5:-false}"

  if [[ ! -f "$compose_file" ]]; then
    log_error "Compose 文件不存在: $compose_file"
    exit 1
  fi

  local compose_dir
  compose_dir=$(cd "$(dirname "$compose_file")"; pwd)
  local compose_base
  compose_base=$(basename "$compose_file")

  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo -e "${BLUE}  等待容器健康检查${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════${NC}"
  echo ""
  log_info "Compose 文件: $compose_base"
  log_info "超时时间: ${timeout}秒"
  log_info "检查间隔: ${interval}秒"
  echo ""

  # 确保容器已启动
  log_info "正在启动容器..."
  cd "$compose_dir"
  if ! docker compose -f "$compose_base" up -d 2>&1; then
    log_error "容器启动失败"
    exit 1
  fi

  # 等待 Docker Compose 完全就绪
  sleep 3

  # 获取所有服务容器
  local containers
  containers=$(docker compose -f "$compose_base" ps -q 2>/dev/null)

  if [[ -z "$containers" ]]; then
    log_warn "未找到运行中的容器"
    return 0
  fi

  # 过滤出有健康检查的容器
  local healthy_containers=()
  local all_containers=()

  while IFS= read -r cid; do
    [[ -z "$cid" ]] && continue
    local cname
    cname=$(get_container_name "$cid")
    local health
    health=$(get_container_health "$cid")
    all_containers+=("$cname")

    if [[ "$health" != "none" ]]; then
      healthy_containers+=("$cname")
    fi
  done <<< "$containers"

  if [[ ${#healthy_containers[@]} -eq 0 ]]; then
    log_warn "没有容器配置健康检查，直接等待所有容器运行"
    # 等待所有容器处于 running 状态
    wait_for_running "$timeout" "$interval"
    return $?
  fi

  echo ""
  log_info "需要等待的容器 (${#healthy_containers[@]} 个):"
  for c in "${healthy_containers[@]}"; do
    echo "  - $c"
  done
  echo ""

  # 开始健康检查循环
  local elapsed=0
  local unready_containers=("${healthy_containers[@]}")

  while [[ $elapsed -lt $timeout ]]; do
    local all_healthy=true

    for container in "${unready_containers[@]}"; do
      local status
      status=$(get_container_health "$container")

      case "$status" in
        healthy)
          unready_containers=("${unready_containers[@]/$container}")
          if [[ "$follow" == "true" ]]; then
            echo -e "  ${GREEN}✓${NC} $container is healthy"
          fi
          ;;
        unhealthy)
          echo ""
          log_error "容器健康检查失败: $container"
          show_container_logs "$container" "$log_lines"
          unready_containers=("${unready_containers[@]/$container}")
          all_healthy=false
          ;;
        starting|"")
          all_healthy=false
          if [[ "$follow" == "true" ]]; then
            echo -e "  ${YELLOW}⟳${NC} $container is starting (${status:-checking})"
          fi
          ;;
        none)
          # 无健康检查的容器，检查运行状态
          local run_status
          run_status=$(get_container_status "$container")
          if [[ "$run_status" != "running" ]]; then
            all_healthy=false
          else
            unready_containers=("${unready_containers[@]/$container}")
          fi
          ;;
      esac
    done

    if [[ $all_healthy == "true" ]] || [[ ${#unready_containers[@]} -eq 0 ]]; then
      echo ""
      echo -e "${GREEN}${BOLD}✓ 所有容器健康检查通过！${NC}"
      echo ""
      return 0
    fi

    if [[ "$follow" == "true" ]]; then
      printf "\r  等待中... %ds / %ds" "$elapsed" "$timeout"
    fi

    sleep "$interval"
    ((elapsed+=interval)) || true
  done

  # 超时处理
  echo ""
  echo ""
  log_error "健康检查超时 (${timeout}秒)"
  echo ""
  echo -e "${RED}${BOLD}未健康的容器:${NC}"

  for container in "${healthy_containers[@]}"; do
    local status
    status=$(get_container_health "$container")
    if [[ "$status" != "healthy" ]]; then
      echo ""
      echo -e "  ${RED}✗${NC} $container: $status"
      show_container_logs "$container" "$log_lines"
    fi
  done

  echo ""
  return 1
}

wait_for_running() {
  local timeout="$1"
  local interval="$2"

  local elapsed=0

  while [[ $elapsed -lt $timeout ]]; do
    local all_running=true
    local running_containers
    running_containers=$(docker compose ps --format '{{.Name}}:{{.Service}}:{{.State}}' 2>/dev/null | grep -v ":running$" || true)

    if [[ -z "$running_containers" ]]; then
      echo ""
      echo -e "${GREEN}${BOLD}✓ 所有容器已运行${NC}"
      return 0
    fi

    sleep "$interval"
    ((elapsed+=interval)) || true
  done

  return 1
}

show_container_logs() {
  local container="$1"
  local lines="${2:-$LOG_LINES}"

  echo ""
  echo -e "  ${YELLOW}最后 ${lines} 行日志:${NC}"
  echo "  ───────────────────────────────────────────"

  local logs
  logs=$(docker logs --tail "$lines" "$container" 2>&1 | tail -n "$lines" || echo "(无法获取日志)")

  while IFS= read -r line; do
    echo "  | $line"
  done <<< "$logs"

  echo "  ───────────────────────────────────────────"
}

# ---------------------------------------------------------------------------
# 主函数
# ---------------------------------------------------------------------------

main() {
  local compose_file=""
  local stack=""
  local timeout="$DEFAULT_TIMEOUT"
  local interval="$CHECK_INTERVAL"
  local log_lines="$LOG_LINES"
  local follow="false"

  # 解析参数
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--timeout)
        timeout="$2"; shift 2 ;;
      -i|--interval)
        interval="$2"; shift 2 ;;
      -l|--log-lines)
        log_lines="$2"; shift 2 ;;
      -s|--stack)
        stack="$2"; shift 2 ;;
      -f|--follow)
        follow="true"; shift ;;
      -h|--help)
        usage; exit 0 ;;
      -*)
        echo "Unknown option: $1"; usage; exit 1 ;;
      *)
        compose_file="$1"; shift ;;
    esac
  done

  # 确定 compose 文件
  if [[ -z "$compose_file" && -n "$stack" ]]; then
    compose_file=$(get_compose_file "$stack")
  elif [[ -z "$compose_file" ]]; then
    compose_file=$(get_compose_file "")
  fi

  if [[ ! -f "$compose_file" ]]; then
    log_error "未找到 compose 文件: $compose_file"
    echo ""
    echo "可用的堆栈:"
    ls -1 ./stacks/ 2>/dev/null || echo "  (无)"
    echo ""
    echo "使用 -s 选项指定堆栈名称，或直接指定 compose 文件路径"
    exit 1
  fi

  wait_for_healthy "$compose_file" "$timeout" "$interval" "$log_lines" "$follow"
  exit $?
}

main "$@"
