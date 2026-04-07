#!/usr/bin/env bash
# =============================================================================
# CN Pull — 国内网络环境镜像加速拉取工具
# 自动将 gcr.io / ghcr.io / k8s.gcr.io 替换为国内可用镜像源
# 支持: 镜像加速、错误重试、并行下载、进度显示
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[cn-pull]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[cn-pull]${NC} $*"; }
log_error() { echo -e "${RED}[cn-pull]${NC} $*" >&2; }
log_debug() { [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${BLUE}[debug]${NC} $*" || true; }

# Configuration
MAX_RETRIES=3
RETRY_DELAY=5
PARALLEL_PULLS=3
VERBOSE=false

# 镜像源映射表 (按优先级排序)
declare -A MIRROR_MAP=(
  ["gcr.io"]="gcr.m.daocloud.io gcr.nju.edu.cn gcr.mirrors.ustc.edu.cn"
  ["ghcr.io"]="ghcr.m.daocloud.io ghcr.nju.edu.cn"
  ["k8s.gcr.io"]="k8s-gcr.m.daocloud.io k8s-gcr.nju.edu.cn"
  ["registry.k8s.io"]="k8s.m.daocloud.io k8s.nju.edu.cn"
  ["quay.io"]="quay.m.daocloud.io quay.nju.edu.cn"
  ["docker.io"]="docker.m.daocloud.io docker.1ms.run docker.awsl9527.cn"
)

check_connectivity() {
  local host=$1
  curl -sf --connect-timeout 3 --max-time 5 "https://$host" &>/dev/null
}

# 测试镜像源速度
test_mirror_speed() {
  local mirror=$1
  local start_time end_time duration
  
  start_time=$(date +%s%N)
  if curl -sf --connect-timeout 2 --max-time 5 "https://$mirror" &>/dev/null; then
    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))
    echo "$duration"
  else
    echo "999999"
  fi
}

# 选择最快的镜像源
select_fastest_mirror() {
  local registry=$1
  local mirrors=${MIRROR_MAP[$registry]:-}
  
  if [[ -z "$mirrors" ]]; then
    echo ""
    return 1
  fi
  
  local fastest_mirror=""
  local fastest_time=999999
  
  for mirror in $mirrors; do
    local speed
    speed=$(test_mirror_speed "$mirror")
    log_debug "Mirror $mirror: ${speed}ms"
    
    if [[ $speed -lt $fastest_time ]]; then
      fastest_time=$speed
      fastest_mirror="$mirror"
    fi
  done
  
  if [[ -n "$fastest_mirror" && $fastest_time -lt 999999 ]]; then
    log_info "Selected fastest mirror for $registry: $fastest_mirror (${fastest_time}ms)"
    echo "$fastest_mirror"
    return 0
  else
    return 1
  fi
}

translate_image() {
  local image=$1
  local use_fastest=${2:-false}
  
  for registry in "${!MIRROR_MAP[@]}"; do
    if [[ "$image" == "$registry"* ]]; then
      local mirror
      
      if [[ "$use_fastest" == "true" ]]; then
        # Select fastest mirror
        mirror=$(select_fastest_mirror "$registry")
        if [[ -z "$mirror" ]]; then
          # Fallback to first mirror in list
          mirror=$(echo "${MIRROR_MAP[$registry]}" | awk '{print $1}')
        fi
      else
        # Use first mirror in list (default behavior)
        mirror=$(echo "${MIRROR_MAP[$registry]}" | awk '{print $1}')
      fi
      
      if [[ -n "$mirror" ]]; then
        echo "${image/$registry/$mirror}"
        return 0
      fi
    fi
  done
  
  # No translation needed
  echo "$image"
}

pull_with_retry() {
  local image=$1
  local max_retries=${2:-$MAX_RETRIES}
  local retry=0
  
  while [[ $retry -lt $max_retries ]]; do
    if docker pull "$image" 2>&1 | tee >(grep -qE "^Error|^failed|no such host" && echo "failed" > /tmp/pull_status_$$ || true); then
      return 0
    fi
    
    retry=$((retry + 1))
    if [[ $retry -lt $max_retries ]]; then
      log_warn "Pull failed, retrying ($retry/$max_retries) in ${RETRY_DELAY}s..."
      sleep $RETRY_DELAY
    fi
  done
  
  return 1
}

pull_with_fallback() {
  local image=$1
  local translated
  local registry=""
  
  # Identify the registry
  for reg in "${!MIRROR_MAP[@]}"; do
    if [[ "$image" == "$reg"* ]]; then
      registry="$reg"
      break
    fi
  done
  
  if [[ -z "$registry" ]]; then
    # No translation needed, pull directly
    log_info "Pulling directly: $image"
    pull_with_retry "$image"
    return $?
  fi
  
  # Get all available mirrors for this registry
  local mirrors=${MIRROR_MAP[$registry]:-}
  
  if [[ -z "$mirrors" ]]; then
    log_warn "No mirrors configured for $registry"
    log_info "Pulling directly: $image"
    pull_with_retry "$image"
    return $?
  fi
  
  # Try each mirror in order
  for mirror in $mirrors; do
    translated="${image/$registry/$mirror}"
    log_info "Trying mirror: $mirror"
    log_info "Pulling: $translated"
    
    if pull_with_retry "$translated" 1; then
      # Tag with original name
      docker tag "$translated" "$image" 2>/dev/null || true
      log_info "Tagged $translated -> $image"
      return 0
    fi
  done
  
  # All mirrors failed, try direct pull
  log_warn "All mirrors failed for $image"
  log_info "Attempting direct pull: $image"
  pull_with_retry "$image"
  return $?
}

# Pull multiple images in parallel
pull_parallel() {
  local images=("$@")
  local pids=()
  local failed=0
  
  log_info "Pulling ${#images[@]} images with parallelism $PARALLEL_PULLS"
  
  for ((i=0; i<${#images[@]}; i+=PARALLEL_PULLS)); do
    pids=()
    
    for ((j=i; j<i+PARALLEL_PULLS && j<${#images[@]}; j++)); do
      (
        pull_with_fallback "${images[$j]}"
      ) &
      pids+=("$!")
    done
    
    # Wait for this batch
    for pid in "${pids[@]}"; do
      if ! wait "$pid"; then
        ((failed++))
      fi
    done
  done
  
  if [[ $failed -gt 0 ]]; then
    log_error "$failed images failed to pull"
    return 1
  fi
  
  return 0
}

pull_compose_images() {
  local compose_file=$1
  local parallel=${2:-false}
  
  log_info "Parsing images from: $compose_file"
  local images
  images=$(grep -E '^\s+image:' "$compose_file" | awk '{print $2}' | tr -d '"\x27')
  
  local image_array=()
  while IFS= read -r image; do
    [[ -z "$image" ]] && continue
    image_array+=("$image")
  done <<< "$images"
  
  log_info "Found ${#image_array[@]} images to pull"
  
  if [[ "$parallel" == "true" && ${#image_array[@]} -gt 1 ]]; then
    pull_parallel "${image_array[@]}"
  else
    local failed=0
    for image in "${image_array[@]}"; do
      if ! pull_with_fallback "$image"; then
        ((failed++))
      fi
    done
    
    if [[ $failed -gt 0 ]]; then
      log_error "$failed images failed to pull"
      return 1
    fi
  fi
  
  return 0
}

usage() {
  echo "Usage:"
  echo "  $0 <image>                  Pull single image with CN acceleration"
  echo "  $0 --compose <file>         Pull all images in a compose file"
  echo "  $0 --stack <stack-name>     Pull all images for a stack"
  echo ""
  echo "Options:"
  echo "  --parallel                  Pull multiple images in parallel"
  echo "  --retries <n>               Number of retries per image (default: $MAX_RETRIES)"
  echo "  --verbose                   Show detailed output"
  echo "  --help                      Show this help"
  exit 1
}

# Parse options
PARALLEL=false
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --parallel|-p)
      PARALLEL=true
      shift
      ;;
    --retries)
      MAX_RETRIES="${2:-}"
      [[ -z "$MAX_RETRIES" ]] && { echo "Error: --retries requires a number"; exit 1; }
      shift 2
      ;;
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      usage
      ;;
    --compose|--stack)
      POSITIONAL_ARGS+=("$1" "$2")
      shift 2
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

# Restore positional arguments
set -- "${POSITIONAL_ARGS[@]}"

[[ $# -lt 1 ]] && usage

case $1 in
  --compose)
    [[ -z "${2:-}" ]] && usage
    pull_compose_images "$2" "$PARALLEL"
    ;;
  --stack)
    [[ -z "${2:-}" ]] && usage
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
    STACK_DIR="$SCRIPT_DIR/../stacks/$2"
    if [[ -f "$STACK_DIR/docker-compose.local.yml" ]]; then
      pull_compose_images "$STACK_DIR/docker-compose.local.yml" "$PARALLEL"
    elif [[ -f "$STACK_DIR/docker-compose.yml" ]]; then
      pull_compose_images "$STACK_DIR/docker-compose.yml" "$PARALLEL"
    else
      log_error "Stack not found: $2"
      exit 1
    fi
    ;;
  *)
    pull_with_fallback "$1"
    ;;
esac
