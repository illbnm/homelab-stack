#!/usr/bin/env bash
# =============================================================================
# Localize Images — 国内网络镜像替换工具
# 将 compose 文件中的 gcr.io/ghcr.io 镜像替换为国内镜像
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
log_step()  { echo -e "\n${BLUE}${BOLD}==>$NC $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/config/cn-mirrors.yml"

# 镜像映射表 (简化版，完整映射从配置文件读取)
declare -A MIRROR_MAP=(
  ["gcr.io"]="gcr.m.daocloud.io"
  ["ghcr.io"]="ghcr.m.daocloud.io"
  ["k8s.gcr.io"]="k8s-gcr.m.daocloud.io"
  ["registry.k8s.io"]="k8s.m.daocloud.io"
  ["quay.io"]="quay.m.daocloud.io"
)

# 从配置文件加载镜像映射
load_mirror_map() {
  if [[ -f "$CONFIG_FILE" ]]; then
    log_info "从配置文件加载镜像映射: $CONFIG_FILE"
    # 解析 YAML 配置文件 (简单解析)
    while IFS= read -r line; do
      if [[ "$line" =~ ^[[:space:]]+([a-zA-Z0-9._/-]+):[[:space:]]+([a-zA-Z0-9._/-]+) ]]; then
        local original="${BASH_REMATCH[1]}"
        local mirror="${BASH_REMATCH[2]}"
        MIRROR_MAP["$original"]="$mirror"
      fi
    done < <(grep -E '^\s+[a-zA-Z0-9._/-]+:\s+[a-zA-Z0-9._/-]+' "$CONFIG_FILE" || true)
    log_info "已加载 ${#MIRROR_MAP[@]} 个镜像映射"
  else
    log_warn "配置文件不存在，使用默认映射表"
  fi
}

# 替换单个镜像地址
translate_image() {
  local image="$1"
  
  for registry in "${!MIRROR_MAP[@]}"; do
    if [[ "$image" == "$registry"* ]]; then
      local mirror="${MIRROR_MAP[$registry]}"
      echo "${image/$registry/$mirror}"
      return
    fi
  done
  
  echo "$image"
}

# 检查 compose 文件是否需要替换
check_compose_file() {
  local file="$1"
  local needs_replace=false
  
  while IFS= read -r line; do
    if [[ "$line" =~ image:[[:space:]]*[\"\']?([^\"\']+) ]]; then
      local image="${BASH_REMATCH[1]}"
      for registry in "${!MIRROR_MAP[@]}"; do
        if [[ "$image" == "$registry"* ]]; then
          needs_replace=true
          break
        fi
      done
    fi
    [[ "$needs_replace" == true ]] && break
  done < "$file"
  
  [[ "$needs_replace" == true ]] && return 0 || return 1
}

# 替换 compose 文件中的镜像
replace_in_file() {
  local file="$1"
  local dry_run="${2:-false}"
  
  log_info "处理文件: $file"
  
  local temp_file=$(mktemp)
  local changes=0
  
  while IFS= read -r line; do
    local new_line="$line"
    
    # 匹配 image: xxx 行
    if [[ "$line" =~ ^(.*image:[[:space:]]*[\"\']?)([^\"\']+)([\"\']?.*)$ ]]; then
      local prefix="${BASH_REMATCH[1]}"
      local image="${BASH_REMATCH[2]}"
      local suffix="${BASH_REMATCH[3]}"
      
      local translated=$(translate_image "$image")
      
      if [[ "$translated" != "$image" ]]; then
        new_line="${prefix}${translated}${suffix}"
        ((changes++))
        
        if [[ "$dry_run" == true ]]; then
          log_info "  预览：$image → $translated"
        else
          log_info "  替换：$image → $translated"
        fi
      fi
    fi
    
    echo "$new_line" >> "$temp_file"
  done < "$file"
  
  if [[ "$dry_run" != true && $changes -gt 0 ]]; then
    mv "$temp_file" "$file"
    log_info "✓ 完成：$changes 个镜像已替换"
  else
    rm -f "$temp_file"
  fi
  
  return $changes
}

# 恢复 compose 文件中的原始镜像
restore_in_file() {
  local file="$1"
  local dry_run="${2:-false}"
  
  log_info "恢复文件：$file"
  
  local temp_file=$(mktemp)
  local changes=0
  
  # 反向映射
  declare -A REVERSE_MAP
  for original in "${!MIRROR_MAP[@]}"; do
    local mirror="${MIRROR_MAP[$original]}"
    REVERSE_MAP["$mirror"]="$original"
  done
  
  while IFS= read -r line; do
    local new_line="$line"
    
    if [[ "$line" =~ ^(.*image:[[:space:]]*[\"\']?)([^\"\']+)([\"\']?.*)$ ]]; then
      local prefix="${BASH_REMATCH[1]}"
      local image="${BASH_REMATCH[2]}"
      local suffix="${BASH_REMATCH[3]}"
      
      for mirror in "${!REVERSE_MAP[@]}"; do
        if [[ "$image" == "$mirror"* ]]; then
          local original="${REVERSE_MAP[$mirror]}"
          local restored="${image/$mirror/$original}"
          new_line="${prefix}${restored}${suffix}"
          ((changes++))
          
          if [[ "$dry_run" == true ]]; then
            log_info "  预览：$image → $restored"
          else
            log_info "  恢复：$image → $restored"
          fi
          break
        fi
      done
    fi
    
    echo "$new_line" >> "$temp_file"
  done < "$file"
  
  if [[ "$dry_run" != true && $changes -gt 0 ]]; then
    mv "$temp_file" "$file"
    log_info "✓ 完成：$changes 个镜像已恢复"
  else
    rm -f "$temp_file"
  fi
  
  return $changes
}

# 备份 compose 文件
backup_file() {
  local file="$1"
  local backup="${file}.backup.$(date +%Y%m%d%H%M%S)"
  cp "$file" "$backup"
  log_info "备份：$backup"
}

# 处理所有 compose 文件
process_all_compose_files() {
  local action="$1"
  local dry_run="${2:-false}"
  
  log_step "搜索 compose 文件..."
  
  local files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find "$PROJECT_ROOT" -name "docker-compose*.yml" -o -name "docker-compose*.yaml" | tr '\n' '\0')
  
  if [[ ${#files[@]} -eq 0 ]]; then
    log_warn "未找到 compose 文件"
    return 1
  fi
  
  log_info "找到 ${#files[@]} 个 compose 文件"
  
  local total_changes=0
  
  for file in "${files[@]}"; do
    if [[ "$action" == "check" ]]; then
      if check_compose_file "$file"; then
        log_info "需要替换：$file"
      fi
    elif [[ "$action" == "replace" ]]; then
      if check_compose_file "$file"; then
        backup_file "$file"
        replace_in_file "$file" "$dry_run"
        ((total_changes++))
      fi
    elif [[ "$action" == "restore" ]]; then
      if [[ -f "${file}.backup."* ]]; then
        restore_in_file "$file" "$dry_run"
        ((total_changes++))
      fi
    fi
  done
  
  log_step "处理完成"
  log_info "总计：$total_changes 个文件已处理"
}

# 显示帮助
usage() {
  cat <<EOF
用法：$0 [选项]

选项:
  --cn          替换为国内镜像
  --restore     恢复原始镜像
  --dry-run     预览变更，不实际修改
  --check       检测哪些文件需要替换
  --file FILE   仅处理指定文件
  --help        显示帮助信息

示例:
  $0 --cn              # 替换所有 compose 文件为国内镜像
  $0 --restore         # 恢复所有 compose 文件为原始镜像
  $0 --cn --dry-run    # 预览替换效果
  $0 --check           # 检查哪些文件需要替换
  $0 --cn --file docker-compose.yml  # 仅处理指定文件

EOF
  exit 0
}

# 主函数
main() {
  echo -e ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   HomeLab Stack - 镜像替换工具                           ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
  echo -e ""
  
  # 加载镜像映射
  load_mirror_map
  
  local action=""
  local dry_run=false
  local target_file=""
  
  # 解析参数
  while [[ $# -gt 0 ]]; do
    case $1 in
      --cn)
        action="replace"
        shift
        ;;
      --restore)
        action="restore"
        shift
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --check)
        action="check"
        shift
        ;;
      --file)
        target_file="$2"
        shift 2
        ;;
      --help|-h)
        usage
        ;;
      *)
        log_error "未知选项：$1"
        usage
        ;;
    esac
  done
  
  if [[ -z "$action" ]]; then
    log_error "请指定操作：--cn | --restore | --check"
    usage
  fi
  
  # 处理单个文件或所有文件
  if [[ -n "$target_file" ]]; then
    if [[ ! -f "$target_file" ]]; then
      log_error "文件不存在：$target_file"
      exit 1
    fi
    
    case $action in
      check)
        if check_compose_file "$target_file"; then
          log_info "需要替换：$target_file"
        else
          log_info "无需替换：$target_file"
        fi
        ;;
      replace)
        if [[ "$dry_run" == false ]]; then
          backup_file "$target_file"
        fi
        replace_in_file "$target_file" "$dry_run"
        ;;
      restore)
        restore_in_file "$target_file" "$dry_run"
        ;;
    esac
  else
    process_all_compose_files "$action" "$dry_run"
  fi
}

main "$@"
