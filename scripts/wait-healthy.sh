#!/usr/bin/env bash
# =============================================================================
# Docker Compose Health Waiter
# Waits for all containers in a stack to become healthy
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TIMEOUT=300
POLL_INTERVAL=5
STACK_NAME=""

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
  cat <<EOF
用法:
  $0 --stack <name> [--timeout <seconds>]

选项:
  --stack <name>      Stack 名称 (必需)
  --timeout <sec>     超时时间，默认 300 秒
  --help              显示帮助信息

示例:
  $0 --stack sso --timeout 600
  $0 --stack monitoring

退出码:
  0 - 所有容器健康
  1 - 超时
  2 - 有容器退出
EOF
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --stack)
      STACK_NAME="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      log_error "未知参数: $1"
      usage
      ;;
  esac
done

if [[ -z "$STACK_NAME" ]]; then
  log_error "必须指定 --stack 参数"
  usage
fi

# Find compose file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
COMPOSE_FILE="$SCRIPT_DIR/../stacks/$STACK_NAME/docker-compose.yml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  log_error "Stack 配置文件不存在: $COMPOSE_FILE"
  exit 2
fi

cd "$(dirname "$COMPOSE_FILE")"

# Get list of services
SERVICES=$(docker compose config --services 2>/dev/null || docker-compose config --services 2>/dev/null)
if [[ -z "$SERVICES" ]]; then
  log_error "无法获取服务列表"
  exit 2
fi

log_info "等待 Stack '$STACK_NAME' 中所有服务健康..."
log_info "服务列表: $(echo "$SERVICES" | tr '\n' ' ')"
log_info "超时: ${TIMEOUT}秒"
echo

# Wait loop
START_TIME=$(date +%s)
ALL_HEALTHY=false

while true; do
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))
  
  if [[ $ELAPSED -ge $TIMEOUT ]]; then
    log_error "超时! 等待超过 ${TIMEOUT}秒"
    
    # Show unhealthy containers
    for service in $SERVICES; do
      container=$(docker compose ps -q "$service" 2>/dev/null | head -1)
      if [[ -n "$container" ]]; then
        status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
        if [[ "$status" != "healthy" ]]; then
          echo -e "\n${RED}=== $service (状态: $status) 最近日志 ===${NC}"
          docker logs --tail 50 "$container" 2>&1 | tail -20
        fi
      fi
    done
    
    exit 1
  fi
  
  # Check all services
  UNHEALTHY_COUNT=0
  EXITED_COUNT=0
  
  for service in $SERVICES; do
    container=$(docker compose ps -q "$service" 2>/dev/null | head -1)
    
    if [[ -z "$container" ]]; then
      echo -e "  ${YELLOW}●${NC} $service - 容器未启动"
      ((UNHEALTHY_COUNT++))
      continue
    fi
    
    # Check container state
    state=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
    
    if [[ "$state" == "exited" || "$state" == "dead" ]]; then
      echo -e "  ${RED}✗${NC} $service - 容器已退出 (exit code: $(docker inspect --format='{{.State.ExitCode}}' "$container" 2>/dev/null || echo '?'))"
      ((EXITED_COUNT++))
      continue
    fi
    
    # Check health status
    health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")
    
    case "$health" in
      healthy)
        echo -e "  ${GREEN}✓${NC} $service - 健康"
        ;;
      starting)
        echo -e "  ${YELLOW}○${NC} $service - 启动中..."
        ((UNHEALTHY_COUNT++))
        ;;
      unhealthy)
        echo -e "  ${RED}✗${NC} $service - 不健康"
        ((UNHEALTHY_COUNT++))
        ;;
      no-healthcheck)
        # No health check defined, assume running = healthy
        if [[ "$state" == "running" ]]; then
          echo -e "  ${GREEN}✓${NC} $service - 运行中 (无健康检查)"
        else
          echo -e "  ${YELLOW}●${NC} $service - $state"
          ((UNHEALTHY_COUNT++))
        fi
        ;;
      *)
        echo -e "  ${YELLOW}?${NC} $service - 未知状态: $health"
        ((UNHEALTHY_COUNT++))
        ;;
    esac
  done
  
  # Check for exited containers
  if [[ $EXITED_COUNT -gt 0 ]]; then
    echo
    log_error "检测到 $EXITED_COUNT 个容器已退出"
    exit 2
  fi
  
  # Check if all healthy
  if [[ $UNHEALTHY_COUNT -eq 0 ]]; then
    echo
    log_info "所有服务健康 ✓"
    exit 0
  fi
  
  echo -e "\n${BLUE}等待中... (${ELAPSED}s/${TIMEOUT}s)${NC}"
  sleep $POLL_INTERVAL
done
