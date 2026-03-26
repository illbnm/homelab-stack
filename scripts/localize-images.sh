#!/usr/bin/env bash
# =============================================================================
# localize-images.sh — Docker 镜像本地化（国内镜像替换）
# 将 docker-compose 文件中的镜像替换为国内可用镜像源
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_diff()  { echo -e "${BLUE}[DIFF]${NC} $"* ; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.."; pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/cn-mirrors.yml"
STACKS_DIR="${PROJECT_ROOT}/stacks"

# ---------------------------------------------------------------------------
# 通用镜像替换映射（用于不在 cn-mirrors.yml 中的镜像）
# ---------------------------------------------------------------------------
translate_image_cn() {
    local img="$1"

    case "$img" in
        gcr.io/*)        echo "gcr.m.daocloud.io/${img#gcr.io/}" ;;
        ghcr.io/*)       echo "ghcr.m.daocloud.io/${img#ghcr.io/}" ;;
        k8s.gcr.io/*)    echo "k8s-gcr.m.daocloud.io/${img#k8s.gcr.io/}" ;;
        registry.k8s.io/*) echo "k8s.m.daocloud.io/${img#registry.k8s.io/}" ;;
        quay.io/*)       echo "quay.m.daocloud.io/${img#quay.io/}" ;;
        docker.io/*)     echo "docker.m.daocloud.io/${img#docker.io/}" ;;
        */*)             echo "docker.m.daocloud.io/${img}" ;;
        *)               echo "$img" ;;
    esac
}

is_cn_mirror() {
    [[ "$1" =~ (daocloud|163\.com|baidubce|mirror\.gcr|m\.daocloud|swr\.cn-north) ]]
}

get_original_image() {
    local img="$1"
    echo "$img" | sed \
        -e 's|gcr\.m\.daocloud\.io/|gcr.io/|' \
        -e 's|ghcr\.m\.daocloud\.io/|ghcr.io/|' \
        -e 's|docker\.m\.daocloud\.io/|docker.io/|' \
        -e 's|hub-mirror\.c\.163\.com/|docker.io/|' \
        -e 's|mirror\.baidubce\.com/|docker.io/|' \
        -e 's|swr\.cn-north-4\.myhuaweicloud\.com/ddn-k8s/||'
}

list_compose_files() {
    find "$STACKS_DIR" -name "docker-compose*.yml" -type f 2>/dev/null || echo ""
}

count_to_replace() {
    local count=0
    local files
    files=$(list_compose_files)
    [[ -z "$files" ]] && echo "0" && return

    for file in $files; do
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*image:[[:space:]]*[\"']?([a-zA-Z0-9._/-:]+) ]]; then
                local img="${BASH_REMATCH[1]}"
                if ! is_cn_mirror "$img"; then
                    count=$((count + 1))
                fi
            fi
        done < "$file"
    done
    echo "$count"
}

process_files_cn() {
    local files
    files=$(list_compose_files)
    [[ -z "$files" ]] && return

    for file in $files; do
        local tmp_file
        tmp_file=$(mktemp)
        local changed=0

        while IFS= read -r line; do
            if [[ "$line" =~ ^([[:space:]]*image:[[:space:]]*)[\"']?([a-zA-Z0-9._/-:]+) ]]; then
                local prefix="${BASH_REMATCH[1]}"
                local img="${BASH_REMATCH[2]}"

                if is_cn_mirror "$img"; then
                    echo "$line"
                    continue
                fi

                local new_img
                new_img=$(translate_image_cn "$img")

                if [[ "$new_img" != "$img" ]]; then
                    echo "${prefix}${new_img}"
                    log_diff "替换: $img → $new_img ($(basename "$file"))"
                    changed=$((changed + 1))
                else
                    echo "$line"
                fi
            else
                echo "$line"
            fi
        done < "$file" > "$tmp_file"

        if [[ $changed -gt 0 ]]; then
            mv "$tmp_file" "$file"
            log_info "已更新: $file ($changed 处变更)"
        else
            rm -f "$tmp_file"
        fi
    done
}

process_files_restore() {
    local files
    files=$(list_compose_files)
    [[ -z "$files" ]] && return

    for file in $files; do
        local tmp_file
        tmp_file=$(mktemp)
        local changed=0

        while IFS= read -r line; do
            if [[ "$line" =~ ^([[:space:]]*image:[[:space:]]*)[\"']?([a-zA-Z0-9._\/-:]+) ]]; then
                local prefix="${BASH_REMATCH[1]}"
                local img="${BASH_REMATCH[2]}"
                local orig_img
                orig_img=$(get_original_image "$img")

                if [[ "$orig_img" != "$img" ]]; then
                    echo "${prefix}${orig_img}"
                    log_diff "恢复: $img → $orig_img ($(basename "$file"))"
                    changed=$((changed + 1))
                else
                    echo "$line"
                fi
            else
                echo "$line"
            fi
        done < "$file" > "$tmp_file"

        if [[ $changed -gt 0 ]]; then
            mv "$tmp_file" "$file"
            log_info "已更新: $file ($changed 处变更)"
        else
            rm -f "$tmp_file"
        fi
    done
}

dry_run() {
    local files
    files=$(list_compose_files)
    [[ -z "$files" ]] && return

    local total=0
    for file in $files; do
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*image:[[:space:]]*[\"']?([a-zA-Z0-9._/-:]+) ]]; then
                local img="${BASH_REMATCH[1]}"
                if ! is_cn_mirror "$img"; then
                    local new_img
                    new_img=$(translate_image_cn "$img")
                    echo -e "  - $img"
                    echo -e "  + $new_img"
                    echo "    文件: $(basename "$file")"
                    echo ""
                    total=$((total + 1))
                fi
            fi
        done < "$file"
    done
    echo "共 $total 处变更"
}

usage() {
    cat <<'EOF'
用法: localize-images.sh <模式>

模式:
  --cn         将所有镜像替换为国内镜像源
  --restore    恢复为原始镜像源
  --dry-run    预览变更（不写入文件）
  --check      检测是否需要替换

示例:
  ./localize-images.sh --cn
  ./localize-images.sh --restore
  ./localize-images.sh --dry-run
  ./localize-images.sh --check
EOF
}

main() {
    local mode=""
    [[ $# -eq 0 ]] && usage && exit 1

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cn)       mode="cn" ;;
            --restore)  mode="restore" ;;
            --dry-run)  mode="dry-run" ;;
            --check)    mode="check" ;;
            -h|--help)  usage; exit 0 ;;
            *)          log_error "未知参数: $1"; usage; exit 1 ;;
        esac
        shift
    done

    [[ -z "$mode" ]] && log_error "请指定模式" && exit 1

    log_info "扫描 compose 文件..."

    case "$mode" in
        check)
            echo ""
            echo -e "${BOLD}镜像检测结果:${NC}"
            local cnt
            cnt=$(count_to_replace)
            if [[ "$cnt" -gt 0 ]]; then
                echo -e "  ${YELLOW}[需要替换]${NC} $cnt 个镜像"
                echo "  建议运行: ./localize-images.sh --cn"
            else
                echo -e "  ${GREEN}[OK]${NC} 所有镜像已使用国内源或无需替换"
            fi
            echo ""
            ;;
        dry-run)
            echo ""
            echo -e "${BOLD}=== 预览变更 ===${NC}"
            echo ""
            dry_run
            echo ""
            ;;
        cn)
            echo ""
            echo -e "${BOLD}=== 执行镜像替换 ===${NC}"
            echo ""
            process_files_cn
            echo ""
            log_info "✓ 完成"
            echo ""
            ;;
        restore)
            echo ""
            echo -e "${BOLD}=== 恢复原始镜像 ===${NC}"
            echo ""
            process_files_restore
            echo ""
            log_info "✓ 完成"
            echo ""
            ;;
    esac
}

main "$@"
