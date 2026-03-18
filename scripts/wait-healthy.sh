#!/usr/bin/env bash
# =============================================================================
# Wait Healthy — 等待 stack 中所有容器健康检查通过
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[wait-healthy]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[wait-healthy]${NC} $*"; }
log_error() { echo -e "${RED}[wait-healthy]${NC} $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.."; pwd)"
INTERVAL=5

usage() {
  cat <<EOF
Usage: $0 --stack <name> [--timeout <seconds>] [--interval <seconds>]

Wait for all containers in a stack to pass health checks.

Options:
  --stack <name>       Stack name (directory under stacks/)
  --timeout <seconds>  Max wait time (default: 300)
  --interval <seconds> Poll interval (default: 5)

Exit codes:
  0  All containers healthy
  1  Timeout — some containers not yet healthy
  2  Container exited unexpectedly
EOF
  exit 1
}

STACK=""
TIMEOUT=300

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) STACK="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) log_error "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$STACK" ]]; then
  log_error "--stack is required"
  usage
fi

STACK_DIR="$PROJECT_DIR/stacks/$STACK"
if [[ ! -d "$STACK_DIR" ]]; then
  log_error "Stack not found: $STACK ($STACK_DIR)"
  exit 1
fi

# 获取 stack 的 compose 文件
COMPOSE_FILE=""
for f in "$STACK_DIR"/docker-compose*.yml "$STACK_DIR"/docker-compose*.yaml; do
  [[ -f "$f" ]] && COMPOSE_FILE="$f" && break
done

if [[ -z "$COMPOSE_FILE" ]]; then
  log_error "No compose file found in stacks/$STACK/"
  exit 1
fi

# 获取 stack 的 project name（取目录名）
PROJECT_NAME=$(docker compose -f "$COMPOSE_FILE" ps --format '{{.Project}}' 2>/dev/null | head -1 || echo "$STACK")

# 等待健康
elapsed=0
log_info "Waiting for stack '$STACK' containers to become healthy (timeout: ${TIMEOUT}s)..."

while [[ $elapsed -lt $TIMEOUT ]]; do
  all_healthy=true
  has_exited=false
  unhealthy_containers=""

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local_name=$(echo "$line" | awk '{print $1}')
    state=$(echo "$line" | awk '{print $2}')
    health=$(echo "$line" | awk '{print $3}')

    case "$state" in
      running)
        case "$health" in
          healthy|"(healthy)") ;;
          "(starting)"|"") 
            all_healthy=false
            unhealthy_containers="$unhealthy_containers $local_name"
            ;;
          "(unhealthy)")
            all_healthy=false
            unhealthy_containers="$unhealthy_containers $local_name"
            ;;
        esac
        ;;
      exited|dead|restarting)
        has_exited=true
        unhealthy_containers="$unhealthy_containers $local_name(state=$state)"
        ;;
    esac
  done < <(docker ps --filter "label=com.docker.compose.project=$PROJECT_NAME" \
    --filter "label=com.docker.compose.project=$STACK" \
    --format '{{.Names}} {{.Status}}' 2>/dev/null || true)

  # 兼容：也用 compose ps
  if docker compose -f "$COMPOSE_FILE" ps --format '{{.Name}} {{.Status}}' &>/dev/null; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local_name=$(echo "$line" | awk '{print $1}')
      status=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
      if [[ "$status" == *"Exited"* || "$status" == *"Dead"* ]]; then
        has_exited=true
        unhealthy_containers="$unhealthy_containers $local_name(status: $status)"
      elif [[ "$status" != *"healthy"* ]]; then
        all_healthy=false
        unhealthy_containers="$unhealthy_containers $local_name"
      fi
    done < <(docker compose -f "$COMPOSE_FILE" ps --format '{{.Name}} {{.Status}}' 2>/dev/null)
  fi

  if $all_healthy && ! $has_exited; then
    log_info "✓ All containers in stack '$STACK' are healthy!"
    exit 0
  fi

  if $has_exited; then
    log_error "Some containers exited unexpectedly:$unhealthy_containers"
    for c in $unhealthy_containers; do
      c=$(echo "$c" | awk '{print $1}')
      log_error "--- Last 50 lines of $c ---"
      docker logs --tail 50 "$c" 2>&1 | tail -50 || true
      echo ""
    done
    exit 2
  fi

  sleep "$INTERVAL"
  elapsed=$((elapsed + INTERVAL))
  # 进度提示
  if (( elapsed % 30 == 0 )); then
    log_info "Still waiting... (${elapsed}s/${TIMEOUT}s)$unhealthy_containers"
  fi
done

log_error "Timeout after ${TIMEOUT}s. Unhealthy containers:$unhealthy_containers"
for c in $unhealthy_containers; do
  c=$(echo "$c" | awk '{print $1}')
  log_error "--- Last 50 lines of $c ---"
  docker logs --tail 50 "$c" 2>&1 | tail -50 || true
  echo ""
done
exit 1
