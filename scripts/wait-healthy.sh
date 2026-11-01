#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — Wait Healthy
# 等待 docker compose 所有容器健康检查通过
# 对应 Issue #8 [BOUNTY $250] Robustness — 环境鲁棒性
# 用法: scripts/wait-healthy.sh --stack <name> --timeout 300 [--dir <path>]
# 退出码: 0=全部健康, 1=超时, 2=容器退出
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[wait-healthy]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[wait-healthy]${NC} $*"; }
log_error() { echo -e "${RED}[wait-healthy]${NC} $*" >&2; }

STACK=""
TIMEOUT=300
DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack) STACK="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --dir) DIR="$2"; shift 2 ;;
    *) log_error "未知参数: $1"; exit 2 ;;
  esac
done

if [[ -z "$STACK" ]]; then
  log_error "用法: wait-healthy.sh --stack <name> --timeout 300 [--dir <path>]"
  exit 2
fi

# 确定 compose 文件目录
COMPOSE_DIR="${DIR:-$STACK}"
if [[ ! -f "$COMPOSE_DIR/docker-compose.yml" && ! -f "$COMPOSE_DIR/compose.yml" && ! -f "$COMPOSE_DIR/docker-compose.yaml" && ! -f "$COMPOSE_DIR/compose.yaml" ]]; then
  # 尝试 stacks/<name>
  COMPOSE_DIR="stacks/$STACK"
fi

log_info "等待 stack '$STACK' 健康 (timeout ${TIMEOUT}s, dir=$COMPOSE_DIR)"

START=$(date +%s)

while true; do
  NOW=$(date +%s)
  ELAPSED=$((NOW - START))
  if [[ "$ELAPSED" -ge "$TIMEOUT" ]]; then
    log_error "超时 (${TIMEOUT}s) — 打印未健康容器日志 (最后 50 行)"
    docker compose -f "$COMPOSE_DIR/docker-compose.yml" ps 2>/dev/null | while read -r line; do
      echo "  $line"
    done
    # 打印未健康容器 logs
    for cid in $(docker compose -f "$COMPOSE_DIR/docker-compose.yml" ps -q 2>/dev/null); do
      local status
      status=$(docker inspect -f '{{.State.Health.Status}}' "$cid" 2>/dev/null || echo "unknown")
      if [[ "$status" != "healthy" ]]; then
        echo -e "  ${YELLOW}容器 $cid 状态: $status — 最后 50 行 logs:${NC}"
        docker logs --tail 50 "$cid" 2>&1 | sed 's/^/    /' | head -50
      fi
    done
    exit 1
  fi

  # 检查所有容器
  ALL_HEALTHY=1
  ANY_EXITED=0
  while IFS= read -r cid; do
    [[ -z "$cid" ]] && continue
    local state
    state=$(docker inspect -f '{{.State.Status}}' "$cid" 2>/dev/null || echo "removed")
    if [[ "$state" == "exited" || "$state" == "dead" || "$state" == "removed" ]]; then
      log_error "容器 $cid 已退出 (state=$state)"
      ANY_EXITED=1
    fi
    local health
    health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}healthy{{end}}' "$cid" 2>/dev/null || echo "unknown")
    if [[ "$health" != "healthy" ]]; then
      ALL_HEALTHY=0
    fi
  done < <(docker compose -f "$COMPOSE_DIR/docker-compose.yml" ps -q 2>/dev/null || true)

  if [[ "$ANY_EXITED" -eq 1 ]]; then
    log_error "有容器退出 — 退出码 2"
    exit 2
  fi

  if [[ "$ALL_HEALTHY" -eq 1 ]]; then
    log_info "全部容器健康 ✓ (耗时 ${ELAPSED}s)"
    exit 0
  fi

  # 每 5 秒轮询
  sleep 5
done
