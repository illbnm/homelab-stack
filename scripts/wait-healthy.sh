#!/usr/bin/env bash
# =============================================================================
# wait-healthy.sh — 等待 Docker Compose 堆栈所有容器达到健康状态
# Usage: ./wait-healthy.sh --stack <name> [--timeout 300] [--interval 5]
#        ./wait-healthy.sh --all [--timeout 600]
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
BASE_DIR="$SCRIPT_DIR/.."

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
BOLD='\033[1m'; NC='\033[0m'

STACK=""
TIMEOUT=300
INTERVAL=5
ALL_STACKS=false
VERBOSE=false

usage() {
  cat << EOF
用法: $0 --stack <name> [选项]

等待 Docker Compose 堆栈中所有容器达到健康状态。

选项:
  --stack <name>    堆栈名称 (如: base, media, sso)
  --all             等待所有已定义堆栈
  --timeout <秒>    最大等待时间 (默认: 300s)
  --interval <秒>   轮询间隔 (默认: 5s)
  --verbose         显示详细输出
  -h, --help        显示帮助

示例:
  $0 --stack base           # 等待 base 堆栈健康
  $0 --stack sso --timeout 600  # 等待 SSO 堆栈，最多 10 分钟
  $0 --all                  # 等待所有堆栈

退出码:
  0  所有容器健康
  1  超时（部分容器不健康）
  2  容器已退出（非运行状态）
  3  堆栈不存在
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) STACK="$2"; shift 2 ;;
    --all) ALL_STACKS=true; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --verbose) VERBOSE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) shift ;;
  esac
done

if [[ "$ALL_STACKS" != "true" && -z "$STACK" ]]; then
  echo -e "${RED}Error: --stack <name> or --all required${NC}" >&2
  usage
  exit 1
fi

# 获取堆栈目录
get_stack_dir() {
  local s="$1"
  local dir="$BASE_DIR/stacks/$s"
  # 支持 docker-compose.local.yml
  if [[ -f "$dir/docker-compose.local.yml" ]]; then
    echo "$dir/docker-compose.local.yml"
  elif [[ -f "$dir/docker-compose.yml" ]]; then
    echo "$dir/docker-compose.yml"
  else
    echo ""
  fi
}

# 获取堆栈中的所有容器名
get_stack_containers() {
  local stack_dir="$1"
  if [[ -z "$stack_dir" || ! -f "$stack_dir" ]]; then
    return
  fi
  # Get container names from compose file
  docker compose -f "$stack_dir" config --quiet 2>/dev/null | \
    docker compose -f - ps --format json 2>/dev/null | \
    python3 -c "import sys,json; [print(c['Name']) for c in (json.loads(l) for l in sys.stdin) if 'Name' in c]" 2>/dev/null || \
    docker compose -f "$stack_dir" ps --format '{{.Name}}' 2>/dev/null
}

# 获取容器状态
get_container_status() {
  local name="$1"
  # Check if container exists
  if ! docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
    echo "missing"
    return
  fi

  local state
  state=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null || echo "unknown")
  local health
  health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$name" 2>/dev/null || echo "unknown")

  echo "$state|$health"
}

# 等待单个容器健康
wait_container() {
  local name="$1"
  local start_time elapsed

  start_time=$(date +%s)

  while true; do
    elapsed=$(($(date +%s) - start_time))

    if [[ $elapsed -ge $TIMEOUT ]]; then
      return 1  # timeout
    fi

    local status
    status=$(get_container_status "$name")
    local state health
    IFS='|' read -r state health <<< "$status"

    case "$state" in
      running)
        if [[ "$health" == "healthy" || "$health" == "no-healthcheck" ]]; then
          return 0  # healthy
        fi
        [[ "$VERBOSE" == "true" ]] && \
          echo -ne "  ${name}: ${YELLOW}health: $health${NC} (${elapsed}s/${TIMEOUT}s)\r"
        ;;
      exited|dead|created)
        return 2  # exited
        ;;
      *)
        [[ "$VERBOSE" == "true" ]] && \
          echo -ne "  ${name}: ${RED}state: $state${NC} (${elapsed}s/${TIMEOUT}s)\r"
        ;;
    esac

    sleep "$INTERVAL"
  done
}

# 等待整个堆栈
wait_stack() {
  local stack_name="$1"
  local compose_file

  compose_file=$(get_stack_dir "$stack_name")

  if [[ -z "$compose_file" ]]; then
    echo -e "${RED}[$stack_name] Stack directory not found${NC}"
    return 3
  fi

  echo -e "${BLUE}[$stack_name]${NC} Waiting for containers to be healthy (timeout: ${TIMEOUT}s)..."

  local stack_dir
  stack_dir=$(dirname "$compose_file")

  # Get containers
  local -a containers
  readarray -t containers < <(get_stack_containers "$compose_file" 2>/dev/null || true)

  if [[ ${#containers[@]} -eq 0 ]]; then
    echo -e "  ${YELLOW}No containers found in stack${NC}"
    return 3
  fi

  local -A results
  local all_healthy=true
  local has_exited=false
  local start_time elapsed

  start_time=$(date +%s)

  for container in "${containers[@]}"; do
    [[ -z "$container" ]] && continue

    local status
    status=$(get_container_status "$container")

    if [[ "$status" == "missing" ]]; then
      echo -e "  ${YELLOW}~${NC} $container: not found"
      continue
    fi

    local result
    result=$(wait_container "$container")
    local code=$?

    case $code in
      0)
        echo -e "  ${GREEN}✓${NC} $container: healthy"
        results[$container]="healthy"
        ;;
      1)
        echo -e "  ${RED}✗${NC} $container: TIMEOUT (not healthy after ${TIMEOUT}s)"
        results[$container]="timeout"
        all_healthy=false
        ;;
      2)
        echo -e "  ${RED}✗${NC} $container: EXITED (container not running)"
        results[$container]="exited"
        all_healthy=false
        has_exited=true
        ;;
    esac
  done

  elapsed=$(($(date +%s) - start_time))

  # Print logs for unhealthy containers
  if [[ "$all_healthy" != "true" ]]; then
    echo ""
    echo -e "${RED}Failed containers:${NC}"
    for container in "${!results[@]}"; do
      if [[ "${results[$container]}" != "healthy" ]]; then
        echo -e "\n  ${RED}=== $container logs (last 30 lines) ===${NC}"
        docker logs --tail 30 "$container" 2>&1 | sed 's/^/  /'
      fi
    done
  fi

  echo ""
  echo -e "  Duration: ${elapsed}s"
  echo -e "  ${BOLD}Results: ${#containers[@]} total, $(echo -n "${results[@]}" | grep -o 'healthy' | wc -l) healthy${NC}"

  [[ "$has_exited" == "true" ]] && return 2
  [[ "$all_healthy" == "true" ]] && return 0 || return 1
}

# 主程序
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         Waiting for Docker Containers — Healthy      ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$ALL_STACKS" == "true" ]]; then
  echo -e "${BLUE}Waiting for all stacks...${NC}"
  echo ""

  local -a stacks
  readarray -t stacks < <(find "$BASE_DIR/stacks" -maxdepth 1 -type d -not -name 'stacks' | xargs -I{} basename {} 2>/dev/null || true)

  local exit_code=0
  for s in "${stacks[@]}"; do
    local compose_file
    compose_file=$(get_stack_dir "$s")
    [[ -z "$compose_file" ]] && continue

    wait_stack "$s"
    local code=$?
    [[ $code -ne 0 ]] && exit_code=$code
    echo ""
  done

  exit $exit_code
else
  wait_stack "$STACK"
  exit $?
fi
