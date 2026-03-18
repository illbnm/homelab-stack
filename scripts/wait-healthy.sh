#!/usr/bin/env bash
# =============================================================================
# Wait Healthy — Docker Compose 健康等待脚本
# 等待所有容器健康检查通过，超时后输出错误日志
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[wait-healthy]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[wait-healthy]${NC} $*" >&2; }
log_error() { echo -e "${RED}[wait-healthy]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[wait-healthy]${NC} $*"; }

# 默认配置
STACK_NAME=""
TIMEOUT=300
INTERVAL=5
COMPOSE_FILE=""

# 解析参数
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stack)
        STACK_NAME="$2"
        shift 2
        ;;
      --timeout)
        TIMEOUT="$2"
        shift 2
        ;;
      --interval)
        INTERVAL="$2"
        shift 2
        ;;
      --file)
        COMPOSE_FILE="$2"
        shift 2
        ;;
      --help|-h)
        show_usage
        exit 0
        ;;
      *)
        log_error "未知参数：$1"
        show_usage
        exit 1
        ;;
    esac
  done
  
  if [[ -z "$STACK_NAME" && -z "$COMPOSE_FILE" ]]; then
    log_error "必须指定 --stack 或 --file"
    show_usage
    exit 1
  fi
}

# 显示使用说明
show_usage() {
  cat << EOF
用法：$0 <选项>

选项:
  --stack <name>      等待指定 stack 的所有容器健康
  --file <path>       等待指定 compose 文件的所有容器健康
  --timeout <seconds> 超时时间（默认：300 秒）
  --interval <secs>   轮询间隔（默认：5 秒）
  --help, -h          显示此帮助信息

示例:
  $0 --stack monitoring --timeout 300
  $0 --file ./stacks/monitoring/docker-compose.yml

退出码:
  0 - 所有容器健康
  1 - 超时
  2 - 容器退出或错误
EOF
}

# 获取 compose 命令
get_compose_cmd() {
  local cmd="docker compose"
  if ! command -v docker &>/dev/null; then
    log_error "Docker 未安装"
    exit 2
  fi
  
  # 添加 compose 文件参数
  if [[ -n "$COMPOSE_FILE" ]]; then
    cmd="$cmd -f $COMPOSE_FILE"
  elif [[ -n "$STACK_NAME" ]]; then
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
    local stack_file="$script_dir/../stacks/$STACK_NAME/docker-compose.local.yml"
    if [[ -f "$stack_file" ]]; then
      cmd="$cmd -f $stack_file"
    else
      stack_file="$script_dir/../stacks/$STACK_NAME/docker-compose.yml"
      if [[ -f "$stack_file" ]]; then
        cmd="$cmd -f $stack_file"
      else
        log_error "Stack 文件不存在：$STACK_NAME"
        exit 2
      fi
    fi
  fi
  
  echo "$cmd"
}

# 获取所有容器状态
get_container_status() {
  local compose_cmd="$1"
  $compose_cmd ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}" 2>/dev/null || echo ""
}

# 检查是否所有容器健康
check_all_healthy() {
  local compose_cmd="$1"
  local status
  status=$($compose_cmd ps --format "{{.Health}}" 2>/dev/null || echo "")
  
  if [[ -z "$status" ]]; then
    # 没有健康检查的容器，检查运行状态
    local running
    running=$($compose_cmd ps --format "{{.Status}}" 2>/dev/null | grep -c "running" || echo "0")
    local total
    total=$($compose_cmd ps -q 2>/dev/null | wc -l || echo "0")
    
    if [[ "$running" -eq "$total" && "$total" -gt 0 ]]; then
      return 0
    else
      return 1
    fi
  fi
  
  # 检查所有健康状态
  if echo "$status" | grep -q "unhealthy"; then
    return 1
  fi
  
  if echo "$status" | grep -q "starting"; then
    return 1
  fi
  
  # 所有容器都是 healthy 或没有健康检查
  return 0
}

# 获取未健康容器日志
get_unhealthy_logs() {
  local compose_cmd="$1"
  
  log_step "获取未健康容器日志（最后 50 行）..."
  echo ""
  
  # 获取所有容器名称
  local containers
  containers=$($compose_cmd ps -q 2>/dev/null || echo "")
  
  if [[ -z "$containers" ]]; then
    log_warn "没有找到容器"
    return
  fi
  
  for container in $containers; do
    local name
    name=$(docker inspect --format '{{.Name}}' "$container" 2>/dev/null | sed 's/^\///')
    local health
    health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$container" 2>/dev/null || echo "unknown")
    
    if [[ "$health" != "healthy" && "$health" != "no-healthcheck" ]]; then
      echo "=============================================="
      echo "容器：$name (健康状态：$health)"
      echo "=============================================="
      docker logs --tail 50 "$container" 2>&1 | head -50
      echo ""
    fi
  done
}

# 检查是否有容器退出
check_exited_containers() {
  local compose_cmd="$1"
  local exited
  exited=$($compose_cmd ps --filter "status=exited" -q 2>/dev/null | wc -l || echo "0")
  
  if [[ "$exited" -gt 0 ]]; then
    log_error "发现 $exited 个容器已退出"
    get_unhealthy_logs "$compose_cmd"
    return 2
  fi
  
  return 0
}

# 主等待循环
wait_loop() {
  local compose_cmd
  compose_cmd=$(get_compose_cmd)
  
  log_step "等待容器健康 (超时：${TIMEOUT}s, 间隔：${INTERVAL}s)..."
  log_info "使用命令：$compose_cmd"
  echo ""
  
  local elapsed=0
  local last_status=""
  
  while [[ $elapsed -lt $TIMEOUT ]]; do
    # 显示进度
    local progress=$((elapsed * 100 / TIMEOUT))
    printf "\r[%3d%%] 等待中... (%d/%d 秒)" "$progress" "$elapsed" "$TIMEOUT"
    
    # 检查容器状态
    if check_all_healthy "$compose_cmd"; then
      echo ""
      echo ""
      log_info "✓ 所有容器健康检查通过！"
      
      # 显示最终状态
      echo ""
      log_step "容器状态:"
      get_container_status "$compose_cmd"
      echo ""
      
      return 0
    fi
    
    # 检查是否有容器退出
    check_exited_containers "$compose_cmd"
    local exit_code=$?
    if [[ $exit_code -eq 2 ]]; then
      echo ""
      log_error "✗ 容器退出，等待失败"
      return 2
    fi
    
    sleep "$INTERVAL"
    elapsed=$((elapsed + INTERVAL))
  done
  
  # 超时
  echo ""
  echo ""
  log_error "✗ 等待超时 (${TIMEOUT}秒)"
  echo ""
  
  # 显示未健康容器日志
  get_unhealthy_logs "$compose_cmd"
  
  # 显示当前状态
  log_step "当前容器状态:"
  get_container_status "$compose_cmd"
  echo ""
  
  return 1
}

# 主函数
main() {
  echo ""
  echo "=============================================="
  echo "  Docker Compose 健康等待工具"
  echo "=============================================="
  echo ""
  
  parse_args "$@"
  
  if wait_loop; then
    exit 0
  else
    exit $?
  fi
}

main "$@"
