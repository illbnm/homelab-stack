#!/usr/bin/env bash
# =============================================================================
# CN Pull — 国内网络环境镜像加速拉取工具
# 自动将 gcr.io / ghcr.io / k8s.gcr.io 替换为国内可用镜像源
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[cn-pull]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[cn-pull]${NC} $*"; }
log_error() { echo -e "${RED}[cn-pull]${NC} $*" >&2; }

# 镜像源映射表
declare -A MIRROR_MAP=(
  ["gcr.io"]="gcr.m.daocloud.io"
  ["ghcr.io"]="ghcr.m.daocloud.io"
  ["k8s.gcr.io"]="k8s-gcr.m.daocloud.io"
  ["registry.k8s.io"]="k8s.m.daocloud.io"
  ["quay.io"]="quay.m.daocloud.io"
  ["docker.io"]="docker.m.daocloud.io"
)

check_connectivity() {
  local host=$1
  curl -sf --connect-timeout 3 --max-time 5 "https://$host" &>/dev/null
}

translate_image() {
  local image=$1
  for registry in "${!MIRROR_MAP[@]}"; do
    if [[ "$image" == "$registry"* ]]; then
      local mirror="${MIRROR_MAP[$registry]}"
      echo "${image/$registry/$mirror}"
      return
    fi
  done
  echo "$image"
}

pull_with_fallback() {
  local image=$1
  local translated
  translated=$(translate_image "$image")

  if [[ "$translated" != "$image" ]]; then
    log_info "Pulling via mirror: $translated"
    if docker pull "$translated"; then
      docker tag "$translated" "$image"
      log_info "Tagged $translated -> $image"
      return 0
    else
      log_warn "Mirror failed, trying direct pull: $image"
    fi
  fi

  log_info "Pulling directly: $image"
  docker pull "$image"
}

pull_compose_images() {
  local compose_file=$1
  log_info "Parsing images from: $compose_file"
  local images
  images=$(grep -E '^\s+image:' "$compose_file" | awk '{print $2}' | tr -d '"\x27')
  while IFS= read -r image; do
    [[ -z "$image" ]] && continue
    pull_with_fallback "$image"
  done <<< "$images"
}

usage() {
  echo "Usage:"
  echo "  $0 <image>                  Pull single image with CN acceleration"
  echo "  $0 --compose <file>         Pull all images in a compose file"
  echo "  $0 --stack <stack-name>     Pull all images for a stack"
  exit 1
}

[[ $# -lt 1 ]] && usage

case $1 in
  --compose)
    [[ -z "${2:-}" ]] && usage
    pull_compose_images "$2"
    ;;
  --stack)
    [[ -z "${2:-}" ]] && usage
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
    STACK_DIR="$SCRIPT_DIR/../stacks/$2"
    if [[ -f "$STACK_DIR/docker-compose.local.yml" ]]; then
      pull_compose_images "$STACK_DIR/docker-compose.local.yml"
    elif [[ -f "$STACK_DIR/docker-compose.yml" ]]; then
      pull_compose_images "$STACK_DIR/docker-compose.yml"
    else
      log_error "Stack not found: $2"
      exit 1
    fi
    ;;
  *)
    pull_with_fallback "$1"
    ;;
esac
