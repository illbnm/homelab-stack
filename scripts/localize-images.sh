#!/usr/bin/env bash
# =============================================================================
# Localize Images — 国内镜像替换脚本
# 将 compose 文件中的 gcr.io/ghcr.io 替换为国内镜像源
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[localize-images]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[localize-images]${NC} $*" >&2; }
log_error() { echo -e "${RED}[localize-images]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[localize-images]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$ROOT_DIR/config/cn-mirrors.yml"
COMPOSE_DIR="$ROOT_DIR/stacks"

# 镜像映射表（默认）
declare -A MIRROR_MAP=(
  ["gcr.io/cadvisor/cadvisor"]="m.daocloud.io/gcr.io/cadvisor/cadvisor"
  ["gcr.io"]="gcr.m.daocloud.io"
  ["ghcr.io/goauthentik/server"]="m.daocloud.io/ghcr.io/goauthentik/server"
  ["ghcr.io/home-assistant/home-assistant"]="m.daocloud.io/ghcr.io/home-assistant/home-assistant"
  ["ghcr.io/linuxserver/"]="m.daocloud.io/ghcr.io/linuxserver/"
  ["ghcr.io/"]="ghcr.m.daocloud.io/"
  ["k8s.gcr.io"]="k8s-gcr.m.daocloud.io"
  ["registry.k8s.io"]="k8s.m.daocloud.io"
  ["quay.io"]="quay.m.daocloud.io"
  ["docker.io"]="docker.m.daocloud.io"
)

# 从配置文件加载镜像映射
load_mirror_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    log_step "加载镜像配置文件：$CONFIG_FILE"
    while IFS=': ' read -r key value; do
      [[ -z "$key" || "$key" =~ ^# || "$key" =~ ^mirrors$ ]] && continue
      key=$(echo "$key" | tr -d ' ')
      value=$(echo "$value" | tr -d ' ')
      [[ -n "$key" && -n "$value" ]] && MIRROR_MAP["$key"]="$value"
    done < "$CONFIG_FILE"
    log_info "已加载 ${#MIRROR_MAP[@]} 个镜像映射规则"
  else
    log_warn "配置文件不存在，使用默认映射表：$CONFIG_FILE"
  fi
}

# 替换单个镜像地址
translate_image() {
  local image="$1"
  
  # 优先匹配完整路径
  for key in "${!MIRROR_MAP[@]}"; do
    if [[ "$image" == "$key"* ]]; then
      local mirror="${MIRROR_MAP[$key]}"
      echo "${image/$key/$mirror}"
      return
    fi
  done
  
  # 未匹配则返回原地址
  echo "$image"
}

# 处理单个 compose 文件
process_compose_file() {
  local file="$1"
  local mode="$2"  # cn|restore|dry-run|check
  local changed=false
  local temp_file="${file}.tmp"
  
  log_step "处理文件：$file"
  
  # 读取文件内容
  local content
  content=$(cat "$file")
  local original_content="$content"
  
  # 根据模式处理
  case "$mode" in
    cn)
      # 替换为国内镜像
      for key in "${!MIRROR_MAP[@]}"; do
        local mirror="${MIRROR_MAP[$key]}"
        if [[ "$content" == *"$key"* ]]; then
          content="${content//$key/$mirror}"
          changed=true
        fi
      done
      ;;
    restore)
      # 恢复原始镜像（反向替换）
      for key in "${!MIRROR_MAP[@]}"; do
        local mirror="${MIRROR_MAP[$key]}"
        if [[ "$content" == *"$mirror"* ]]; then
          content="${content//$mirror/$key}"
          changed=true
        fi
      done
      ;;
    dry-run)
      # 预览变更
      for key in "${!MIRROR_MAP[@]}"; do
        local mirror="${MIRROR_MAP[$key]}"
        if [[ "$content" == *"$key"* ]]; then
          echo "  将替换：$key → $mirror"
          changed=true
        fi
      done
      return 0
      ;;
    check)
      # 检测是否需要替换
      for key in "${!MIRROR_MAP[@]}"; do
        if [[ "$content" == *"$key"* ]]; then
          echo "  发现需要替换的镜像：$key"
          changed=true
        fi
      done
      return 0
      ;;
  esac
  
  # 写入文件（非 dry-run/check 模式）
  if [[ "$mode" != "dry-run" && "$mode" != "check" ]]; then
    if [[ "$changed" == true ]]; then
      echo "$content" > "$temp_file"
      mv "$temp_file" "$file"
      log_info "✓ 已更新：$file"
    else
      log_info "○ 无需更改：$file"
    fi
  fi
  
  return 0
}

# 处理所有 compose 文件
process_all_compose_files() {
  local mode="$1"
  local count=0
  
  log_step "扫描 compose 文件..."
  
  while IFS= read -r -d '' file; do
    process_compose_file "$file" "$mode"
    ((count++))
  done < <(find "$COMPOSE_DIR" -name "docker-compose*.yml" -print0)
  
  log_info "共处理 $count 个文件"
}

# 显示使用说明
show_usage() {
  cat << EOF
用法：$0 <选项>

选项:
  --cn          替换为国内镜像源
  --restore     恢复原始镜像地址
  --dry-run     预览变更（不实际修改）
  --check       检测当前是否需要替换

示例:
  $0 --cn          # 替换所有 compose 文件为国内镜像
  $0 --restore     # 恢复所有 compose 文件为原始镜像
  $0 --dry-run     # 预览将要做出的更改
  $0 --check       # 检查当前状态

配置文件：$CONFIG_FILE
EOF
}

# 主函数
main() {
  if [[ $# -lt 1 ]]; then
    show_usage
    exit 1
  fi
  
  local mode=""
  
  case "$1" in
    --cn)
      mode="cn"
      log_info "开始替换为国内镜像..."
      ;;
    --restore)
      mode="restore"
      log_info "开始恢复原始镜像..."
      ;;
    --dry-run)
      mode="dry-run"
      log_info "预览变更..."
      ;;
    --check)
      mode="check"
      log_info "检测镜像替换状态..."
      ;;
    --help|-h)
      show_usage
      exit 0
      ;;
    *)
      log_error "未知选项：$1"
      show_usage
      exit 1
      ;;
  esac
  
  # 加载镜像配置
  load_mirror_config
  
  # 处理所有 compose 文件
  process_all_compose_files "$mode"
  
  log_info "操作完成！"
}

main "$@"
