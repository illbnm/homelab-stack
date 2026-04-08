#!/usr/bin/env bash
# =============================================================================
# Image Localization Script
# Replaces gcr.io/ghcr.io images with CN mirrors in compose files
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/cn-mirrors.yml"
STACKS_DIR="$SCRIPT_DIR/../stacks"

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Image replacement mappings
declare -A IMAGE_MAP=(
  # gcr.io → CN mirrors
  ["gcr.io/cadvisor/cadvisor"]="gcr.m.daocloud.io/cadvisor/cadvisor"
  ["gcr.io/google-containers/pause"]="gcr.m.daocloud.io/google-containers/pause"
  
  # ghcr.io → CN mirrors
  ["ghcr.io/goauthentik/server"]="ghcr.m.daocloud.io/goauthentik/server"
  ["ghcr.io/goauthentik/worker"]="ghcr.m.daocloud.io/goauthentik/worker"
  ["ghcr.io/home-assistant/home-assistant"]="ghcr.m.daocloud.io/home-assistant/home-assistant"
  ["ghcr.io/linuxserver/nextcloud"]="ghcr.m.daocloud.io/linuxserver/nextcloud"
  ["ghcr.io/linuxserver/sonarr"]="ghcr.m.daocloud.io/linuxserver/sonarr"
  ["ghcr.io/linuxserver/radarr"]="ghcr.m.daocloud.io/linuxserver/radarr"
  ["ghcr.io/linuxserver/lidarr"]="ghcr.m.daocloud.io/linuxserver/lidarr"
  ["ghcr.io/linuxserver/prowlarr"]="ghcr.m.daocloud.io/linuxserver/prowlarr"
  ["ghcr.io/linuxserver/qbittorrent"]="ghcr.m.daocloud.io/linuxserver/qbittorrent"
  ["ghcr.io/linuxserver/jellyfin"]="ghcr.m.daocloud.io/linuxserver/jellyfin"
  ["ghcr.io/linuxserver/heimdall"]="ghcr.m.daocloud.io/linuxserver/heimdall"
  ["ghcr.io/linuxserver/overseerr"]="ghcr.m.daocloud.io/linuxserver/overseerr"
  ["ghcr.io/linuxserver/tautulli"]="ghcr.m.daocloud.io/linuxserver/tautulli"
  ["ghcr.io/linuxserver/jackett"]="ghcr.m.daocloud.io/linuxserver/jackett"
  
  # k8s.gcr.io → CN mirrors
  ["k8s.gcr.io/pause"]="registry.cn-hangzhou.aliyuncs.com/google_containers/pause"
  ["k8s.gcr.io/kube-apiserver"]="registry.cn-hangzhou.aliyuncs.com/google_containers/kube-apiserver"
  ["k8s.gcr.io/kube-controller-manager"]="registry.cn-hangzhou.aliyuncs.com/google_containers/kube-controller-manager"
  ["k8s.gcr.io/kube-scheduler"]="registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler"
  ["k8s.gcr.io/kube-proxy"]="registry.cn-hangzhou.aliyuncs.com/google_containers/kube-proxy"
  ["k8s.gcr.io/etcd"]="registry.cn-hangzhou.aliyuncs.com/google_containers/etcd"
  ["k8s.gcr.io/coredns"]="registry.cn-hangzhou.aliyuncs.com/google_containers/coredns"
  
  # quay.io → CN mirrors
  ["quay.io/prometheus/prometheus"]="quay.m.daocloud.io/prometheus/prometheus"
  ["quay.io/prometheus/alertmanager"]="quay.m.daocloud.io/prometheus/alertmanager"
  ["quay.io/prometheus/node-exporter"]="quay.m.daocloud.io/prometheus/node-exporter"
)

# Registry-level fallback rules
replace_generic() {
  local content=$1
  # Replace gcr.io/* with gcr.m.daocloud.io/*
  content=$(echo "$content" | sed 's|gcr\.io/|gcr.m.daocloud.io/|g')
  # Replace ghcr.io/* with ghcr.m.daocloud.io/*
  content=$(echo "$content" | sed 's|ghcr\.io/|ghcr.m.daocloud.io/|g')
  # Replace k8s.gcr.io/* with Aliyun mirror
  content=$(echo "$content" | sed 's|k8s\.gcr\.io/|registry.cn-hangzhou.aliyuncs.com/google_containers/|g')
  # Replace quay.io/* with quay.m.daocloud.io/*
  content=$(echo "$content" | sed 's|quay\.io/|quay.m.daocloud.io/|g')
  echo "$content"
}

find_compose_files() {
  find "$STACKS_DIR" -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null
}

check_needs_replacement() {
  local file=$1
  if grep -qE 'gcr\.io|ghcr\.io|k8s\.gcr\.io|quay\.io' "$file" 2>/dev/null; then
    return 0
  fi
  return 1
}

action_check() {
  log_info "检查镜像源..."
  local found=0
  
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    
    if check_needs_replacement "$file"; then
      log_warn "发现需要替换的镜像: $file"
      grep -E 'gcr\.io|ghcr\.io|k8s\.gcr\.io|quay\.io' "$file" || true
      ((found++))
    fi
  done < <(find_compose_files)
  
  if [[ $found -gt 0 ]]; then
    echo -e "\n${YELLOW}检测到 $found 个文件需要镜像替换${NC}"
    echo "运行: $0 --cn 进行替换"
    exit 1
  else
    log_info "所有镜像已使用国内源 ✓"
    exit 0
  fi
}

action_dry_run() {
  log_info "预览镜像替换 (dry-run)..."
  
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    
    if check_needs_replacement "$file"; then
      echo -e "\n${BOLD}文件: $file${NC}"
      local original changed
      original=$(cat "$file")
      changed=$(replace_generic "$original")
      
      if [[ "$original" != "$changed" ]]; then
        diff -u <(echo "$original") <(echo "$changed") || true
      fi
    fi
  done < <(find_compose_files)
  
  log_info "预览完成，未修改任何文件"
}

action_cn() {
  log_info "替换为国内镜像..."
  
  while IFS= read -r file; do
    [[ -z "$file" ]] || [[ ! -f "$file" ]] && continue
    
    if check_needs_replacement "$file"; then
      log_info "处理: $file"
      
      # Backup
      cp "$file" "${file}.bak"
      
      # Replace
      local content
      content=$(cat "$file")
      content=$(replace_generic "$content")
      echo "$content" > "$file"
      
      log_info "✓ 已替换并备份到: ${file}.bak"
    fi
  done < <(find_compose_files)
  
  log_info "镜像替换完成 ✓"
}

action_restore() {
  log_info "恢复原始镜像..."
  
  while IFS= read -r bak_file; do
    [[ -z "$bak_file" ]] && continue
    
    local original_file="${bak_file%.bak}"
    if [[ -f "$bak_file" ]]; then
      mv "$bak_file" "$original_file"
      log_info "✓ 已恢复: $original_file"
    fi
  done < <(find "$STACKS_DIR" -name "*.bak" 2>/dev/null)
  
  log_info "恢复完成 ✓"
}

usage() {
  cat <<EOF
用法:
  $0 --cn        替换为国内镜像
  $0 --restore   恢复原始镜像
  $0 --dry-run   预览变更不实际修改
  $0 --check     检测当前是否需要替换

选项:
  --cn        将所有 gcr.io/ghcr.io 替换为国内镜像源
  --restore   从 .bak 文件恢复原始配置
  --dry-run   显示将会进行的替换但不修改文件
  --check     检查是否有需要替换的镜像
  --help      显示此帮助信息

示例:
  $0 --check
  $0 --dry-run
  $0 --cn
  $0 --restore
EOF
  exit 1
}

# Parse arguments
case "${1:-}" in
  --cn)
    action_cn
    ;;
  --restore)
    action_restore
    ;;
  --dry-run)
    action_dry_run
    ;;
  --check)
    action_check
    ;;
  --help|-h)
    usage
    ;;
  *)
    usage
    ;;
esac
