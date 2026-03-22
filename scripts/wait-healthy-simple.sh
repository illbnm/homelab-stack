#!/usr/bin/env bash
# =============================================================================
# Wait Healthy — Docker Compose 健康检查等待工具 (简化版)
# 等待所有容器健康检查通过，支持超时和详细日志
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# 等待 stack 健康
wait_healthy() {
  local stack="$1"
  local timeout="${2:-300}"
  local interval="${3:-5}"
  
  log_info "等待 Stack '$stack' 健康检查通过 (超时：${timeout}s)"
  
  local start_time=$(date +%s)
  local elapsed=0
  
  while [[ $elapsed -lt $timeout ]]; do
    # 获取容器列表
    local containers=$(docker compose -p "$stack" ps -q 2>/dev/null || true)
    
    if [[ -z "$containers" ]]; then
      log_warn "未找到 Stack '$stack' 的容器"
      return 1
    fi
    
    local total=$(echo "$containers" | wc -l)
    local healthy=0
    
    # 检查每个容器
    while IFS= read -r container; do
      [[ -z "$container" ]] && continue
      
      local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null || echo "unknown")
      
      if [[ "$health" == "healthy" ]]; then
        ((healthy++))
      elif [[ "$health" == "unhealthy" ]]; then
        local name=$(docker inspect --format='{{.Name}}' "$container" | sed 's/^\///')
        log_error "容器 $name 健康检查失败"
        return 1
      fi
    done <<< "$containers"
    
    # 显示进度
    local percentage=$((healthy * 100 / total))
    printf "\r  进度：[%-40s] %3d%% (%d/%d)" \
      "$(printf '%*s' $((percentage / 5)) | tr ' ' '█')$(printf '%*s' $((8 - percentage / 5)) | tr ' ' '░')" \
      "$percentage" "$healthy" "$total"
    
    # 检查是否全部健康
    if [[ $healthy -eq $total ]]; then
      echo ""
      log_info "${GREEN}✓ 所有容器健康!${NC}"
      return 0
    fi
    
    sleep "$interval"
    elapsed=$(($(date +%s) - start_time))
  done
  
  echo ""
  log_error "健康检查超时 (${timeout}s)"
  return 1
}

# 显示帮助
usage() {
  cat <<EOF
用法：\$0 --stack <name> [--timeout <seconds>] [--interval <seconds>]

选项:
  --stack NAME     Stack 名称 (必需)
  --timeout SECS   超时时间 (默认：300)
  --interval SECS  检查间隔 (默认：5)
  --help           显示帮助

示例:
  \$0 --stack base --timeout 300
  \$0 --stack media

EOF
  exit 0
}

# 主函数
main() {
  local stack=""
  local timeout=300
  local interval=5
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --stack) stack="$2"; shift 2 ;;
      --timeout) timeout="$2"; shift 2 ;;
      --interval) interval="$2"; shift 2 ;;
      --help|-h) usage ;;
      *) log_error "未知选项：$1"; usage ;;
    esac
  done
  
  if [[ -z "$stack" ]]; then
    log_error "请指定 --stack 参数"
    usage
  fi
  
  wait_healthy "$stack" "$timeout" "$interval"
}

main "$@"
