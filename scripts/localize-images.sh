#!/usr/bin/env bash
# =============================================================================
# Localize Images — 镜像源本地化工具
# 将 docker-compose 文件中的 gcr.io/ghcr.io 等替换为国内镜像源
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[localize-images]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[localize-images]${NC} $*"; }
log_error() { echo -e "${RED}[localize-images]${NC} $*" >&2; }

declare -A MIRROR_MAP=(
    ["gcr.io"]="gcr.m.daocloud.io"
    ["ghcr.io"]="ghcr.m.daocloud.io"
    ["k8s.gcr.io"]="k8s-gcr.m.daocloud.io"
    ["registry.k8s.io"]="k8s.m.daocloud.io"
    ["quay.io"]="quay.m.daocloud.io"
    ["docker.io"]="docker.m.daocloud.io"
)

BACKUP_DIR="$ROOT_DIR/.localize-backup"
DRY_RUN=false

usage() {
    cat <<EOF
用法: $0 [选项]

选项:
  --cn           替换为国内镜像源 (DaoCloud)
  --restore      恢复原始镜像源 (从备份)
  --dry-run      仅显示将要进行的更改，不实际执行
  --help         显示帮助信息

示例:
  $0 --cn                    # 替换所有 compose 文件中的镜像
  $0 --restore               # 恢复原始镜像
  $0 --cn --dry-run          # 预览更改

EOF
}

translate_image() {
    local image="$1"
    local translated="$image"
    for registry in "${!MIRROR_MAP[@]}"; do
        if [[ "$image" == "${registry}"* ]]; then
            translated="${image/${registry}/${MIRROR_MAP[$registry]}}"
            break
        fi
    done
    echo "$translated"
}

process_compose_file() {
    local file="$1"
    local action="$2"
    local changed=0

    if [[ ! -f "$file" ]]; then
        log_warn "文件不存在: $file"
        return 0
    fi

    local temp_file
    temp_file=$(mktemp)

    if [[ "$action" == "cn" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp "$file" "$BACKUP_DIR/$(basename "$file").bak.$(date +%Y%m%d%H%M%S)"

        while IFS= read -r line; do
            local original_image
            original_image=$(echo "$line" | sed -n 's/.*image:[[:space:]]*["'"'"']*\([^"'"'"'# ]*\)["'"'"']*/\1/p')
            if [[ -n "$original_image" ]]; then
                local translated
                translated=$(translate_image "$original_image")
                if [[ "$translated" != "$original_image" ]]; then
                    ((changed++))
                    if [[ "$DRY_RUN" == "true" ]]; then
                        log_info "将替换: $original_image -> $translated"
                    fi
                    line="${line//$original_image/$translated}"
                fi
            fi
            echo "$line"
        done < "$file" > "$temp_file"

        if [[ "$changed" -gt 0 ]] && [[ "$DRY_RUN" == "false" ]]; then
            mv "$temp_file" "$file"
            log_info "已处理: $file ($changed 处更改)"
        elif [[ "$changed" -gt 0 ]] && [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] $file: $changed 处将更改"
        fi

    elif [[ "$action" == "restore" ]]; then
        local latest_bak
        latest_bak=$(ls -t "$BACKUP_DIR"/$(basename "$file").bak.* 2>/dev/null | head -1)

        if [[ -z "$latest_bak" ]]; then
            log_warn "无备份文件: $file"
            return 0
        fi

        cp "$latest_bak" "$file"
        log_info "已恢复: $file"
        ((changed++))
    fi

    [[ -f "$temp_file" ]] && rm -f "$temp_file"
    return $changed
}

main() {
    local action=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cn)       action="cn"; shift ;;
            --restore)  action="restore"; shift ;;
            --dry-run)  DRY_RUN=true; shift ;;
            --help|-h)  usage; exit 0 ;;
            *)          log_error "未知选项: $1"; usage; exit 1 ;;
        esac
    done

    if [[ -z "$action" ]]; then
        log_error "请指定操作: --cn 或 --restore"
        usage
        exit 1
    fi

    echo ""
    echo "========================================"
    echo "  镜像源本地化工具"
    echo "========================================"
    echo ""

    [[ "$DRY_RUN" == "true" ]] && log_warn "DRY RUN 模式"
    [[ "$action" == "restore" ]] && log_info "恢复原始镜像源..."

    local compose_files
    mapfile -t compose_files < <(find "$ROOT_DIR" -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null | grep -v node_modules | grep -v ".localize-backup")

    if [[ ${#compose_files[@]} -eq 0 ]]; then
        log_warn "未找到 docker-compose 文件"
        exit 0
    fi

    local total_changed=0
    for file in "${compose_files[@]}"; do
        process_compose_file "$file" "$action"
        total_changed=$((total_changed + $?))
    done

    echo ""
    if [[ "$DRY_RUN" == "false" ]]; then
        if [[ "$action" == "cn" ]]; then
            log_info "完成! 处理了 ${#compose_files[@]} 个文件，$total_changed 处更改"
            [[ $total_changed -gt 0 ]] && log_info "备份已保存到: $BACKUP_DIR"
        else
            log_info "完成! 已恢复 ${#compose_files[@]} 个文件"
        fi
    else
        log_info "DRY RUN 完成"
    fi
}

main "$@"
