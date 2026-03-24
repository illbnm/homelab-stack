#!/usr/bin/env bash
# wait-healthy.sh — Wait for all containers in a stack to become healthy
# Usage: ./scripts/wait-healthy.sh --stack <name> --timeout <seconds>
# Exit codes: 0=all healthy, 1=timeout, 2=container exited
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Defaults
STACK=""
TIMEOUT=300
POLL_INTERVAL=5

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)    STACK="$2"; shift 2 ;;
    --timeout)  TIMEOUT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --stack <name> --timeout <seconds>"
      echo ""
      echo "Options:"
      echo "  --stack     Stack/project name (Docker Compose project name)"
      echo "  --timeout   Max seconds to wait (default: 300)"
      echo ""
      echo "Exit codes:"
      echo "  0  All containers healthy"
      echo "  1  Timeout reached"
      echo "  2  Container exited unexpectedly"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$STACK" ]]; then
  echo -e "${RED}Error: --stack is required${RESET}"
  echo "Usage: $0 --stack <name> --timeout <seconds>"
  exit 1
fi

check_container_health() {
  local container="$1"
  local state
  state=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container" 2>/dev/null || echo "missing")
  echo "$state"
}

print_unhealthy_logs() {
  local containers=("$@")
  echo ""
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${RED}${BOLD}📋 未健康容器日志 (最后 50 行)${RESET}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

  for container in "${containers[@]}"; do
    echo ""
    echo -e "${YELLOW}── ${container} ──${RESET}"
    docker logs --tail 50 "$container" 2>&1 || echo "(无法获取日志)"
  done
  echo ""
}

echo ""
echo -e "${BOLD}⏳ 等待 stack '${STACK}' 所有容器健康...${RESET}"
echo -e "   超时: ${TIMEOUT}s | 轮询间隔: ${POLL_INTERVAL}s"
echo ""

elapsed=0

while [[ $elapsed -lt $TIMEOUT ]]; do
  mapfile -t containers < <(docker compose -p "$STACK" ps --format '{{.Name}}' 2>/dev/null || true)

  if [[ ${#containers[@]} -eq 0 || ( ${#containers[@]} -eq 1 && -z "${containers[0]}" ) ]]; then
    echo -e "${YELLOW}⚠️  未找到 stack '${STACK}' 的容器，等待中...${RESET}"
    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
    continue
  fi

  all_healthy=true
  unhealthy_containers=()
  exited_containers=()

  for container in "${containers[@]}"; do
    [[ -z "$container" ]] && continue
    health=$(check_container_health "$container")

    case "$health" in
      healthy)
        echo -e "  ${GREEN}✓${RESET} $container — healthy"
        ;;
      running)
        echo -e "  ${CYAN}◌${RESET} $container — running (no healthcheck)"
        ;;
      exited|dead)
        echo -e "  ${RED}✗${RESET} $container — $health"
        exited_containers+=("$container")
        all_healthy=false
        ;;
      starting)
        echo -e "  ${YELLOW}◌${RESET} $container — starting..."
        all_healthy=false
        unhealthy_containers+=("$container")
        ;;
      *)
        echo -e "  ${YELLOW}?${RESET} $container — $health"
        all_healthy=false
        unhealthy_containers+=("$container")
        ;;
    esac
  done

  if [[ ${#exited_containers[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}${BOLD}✗ 检测到容器退出${RESET}"
    print_unhealthy_logs "${exited_containers[@]}"
    exit 2
  fi

  if $all_healthy; then
    echo ""
    echo -e "${GREEN}${BOLD}✅ Stack '${STACK}' 所有容器健康 (${elapsed}s)${RESET}"
    echo ""
    exit 0
  fi

  echo -e "  ${CYAN}... 等待中 (${elapsed}/${TIMEOUT}s)${RESET}"
  echo ""
  sleep "$POLL_INTERVAL"
  elapsed=$((elapsed + POLL_INTERVAL))
done

# Timeout reached
echo ""
echo -e "${RED}${BOLD}⏰ 超时 (${TIMEOUT}s) — 以下容器未健康:${RESET}"

mapfile -t all_containers < <(docker compose -p "$STACK" ps --format '{{.Name}}' 2>/dev/null || true)
still_unhealthy=()
for container in "${all_containers[@]}"; do
  [[ -z "$container" ]] && continue
  health=$(check_container_health "$container")
  if [[ "$health" != "healthy" ]]; then
    still_unhealthy+=("$container")
    echo -e "  ${RED}✗${RESET} $container — $health"
  fi
done

if [[ ${#still_unhealthy[@]} -gt 0 ]]; then
  print_unhealthy_logs "${still_unhealthy[@]}"
fi

exit 1
