#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack Manager
# =============================================================================
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
STACKS_DIR="$BASE_DIR/stacks"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
  echo -e "${BOLD}Usage:${NC} $0 <command> [stack]"
  echo ""
  echo "Commands:"
  echo "  start <stack>    Start a stack"
  echo "  stop <stack>     Stop a stack"
  echo "  restart <stack>  Restart a stack"
  echo "  status <stack>   Show stack status"
  echo "  logs <stack>     Show stack logs"
  echo "  list             List all available stacks"
  echo "  start-all        Start all stacks in order"
  echo "  stop-all         Stop all stacks"
  echo ""
  echo "Available stacks:"
  for d in "$STACKS_DIR"/*/; do
    echo "  - $(basename $d)"
  done
  exit 1
}

get_compose_file() {
  local stack=$1
  local dir="$STACKS_DIR/$stack"
  if [[ -f "$dir/docker-compose.local.yml" ]]; then
    echo "$dir/docker-compose.local.yml"
  elif [[ -f "$dir/docker-compose.yml" ]]; then
    echo "$dir/docker-compose.yml"
  else
    log_error "No compose file found for stack: $stack"
    exit 1
  fi
}

stack_start() {
  local stack=$1
  local compose_file
  compose_file=$(get_compose_file "$stack")
  log_info "Starting stack: $stack"
  # Load .env if exists
  local env_file="$BASE_DIR/config/.env"
  [[ -f "$env_file" ]] && set -a && source "$env_file" && set +a
  docker compose -f "$compose_file" up -d --remove-orphans
  log_info "Stack $stack started"
}

stack_stop() {
  local stack=$1
  local compose_file
  compose_file=$(get_compose_file "$stack")
  log_info "Stopping stack: $stack"
  docker compose -f "$compose_file" down
}

stack_restart() {
  stack_stop "$1"
  stack_start "$1"
}

stack_status() {
  local stack=$1
  local compose_file
  compose_file=$(get_compose_file "$stack")
  docker compose -f "$compose_file" ps
}

stack_logs() {
  local stack=$1
  local compose_file
  compose_file=$(get_compose_file "$stack")
  docker compose -f "$compose_file" logs --tail=100 -f
}

stack_list() {
  echo -e "${BOLD}Available Stacks:${NC}"
  for d in "$STACKS_DIR"/*/; do
    local name
    name=$(basename "$d")
    if docker compose -f "$(get_compose_file $name 2>/dev/null)" ps -q 2>/dev/null | grep -q .; then
      echo -e "  ${GREEN}●${NC} $name (running)"
    else
      echo -e "  ${RED}○${NC} $name (stopped)"
    fi
  done
}

start_all() {
  local order=(base databases sso monitoring network storage productivity media ai home-automation notifications dashboard)
  for stack in "${order[@]}"; do
    if [[ -d "$STACKS_DIR/$stack" ]]; then
      stack_start "$stack" || log_warn "Failed to start $stack, continuing..."
      sleep 2
    fi
  done
}

stop_all() {
  local order=(dashboard notifications home-automation ai media productivity storage network monitoring sso databases base)
  for stack in "${order[@]}"; do
    if [[ -d "$STACKS_DIR/$stack" ]]; then
      stack_stop "$stack" 2>/dev/null || true
    fi
  done
}

[[ $# -lt 1 ]] && usage

CMD=$1
STACK=${2:-}

case $CMD in
  start)   [[ -z $STACK ]] && usage; stack_start "$STACK" ;;
  stop)    [[ -z $STACK ]] && usage; stack_stop "$STACK" ;;
  restart) [[ -z $STACK ]] && usage; stack_restart "$STACK" ;;
  status)  [[ -z $STACK ]] && usage; stack_status "$STACK" ;;
  logs)    [[ -z $STACK ]] && usage; stack_logs "$STACK" ;;
  list)    stack_list ;;
  start-all) start_all ;;
  stop-all)  stop_all ;;
  *) usage ;;
esac
