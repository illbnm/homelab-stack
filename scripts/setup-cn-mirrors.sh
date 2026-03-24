#!/usr/bin/env bash
# =============================================================================
# CN Mirror Setup — Docker 镜像加速配置工具
# 交互式配置中国大陆网络环境的 Docker 镜像加速
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[setup-cn-mirrors]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[setup-cn-mirrors]${NC} $*"; }
log_error() { echo -e "${RED}[setup-cn-mirrors]${NC} $*" >&2; }

DOCKER_DAEMON="/etc/docker/daemon.json"
MIRROR_SOURCES=(
    "docker.m.daocloud.io"
    "hub-mirror.c.163.com"
    "mirror.baidubce.com"
    "mirror.gcr.io"
)

is_cn_network() {
    if curl -sf --connect-timeout 5 --max-time 10 "https://www.baidu.com" &>/dev/null; then
        return 0
    fi
    return 1
}

get_current_mirrors() {
    if [[ -f "$DOCKER_DAEMON" ]]; then
        python3 -c "import json,sys; d=json.load(open('$DOCKER_DAEMON')); print(' '.join(d.get('registry-mirrors', [])))" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

verify_docker_pull() {
    local image="${1:-hello-world}"
    log_info "验证 Docker pull 能力..."
    if docker pull "$image" &>/dev/null; then
        log_info "Docker pull 正常"
        return 0
    else
        log_warn "Docker pull 失败，请检查网络和镜像配置"
        return 1
    fi
}

write_mirror_config() {
    local mirror="$1"
    local backup=""
    if [[ -f "$DOCKER_DAEMON" ]]; then
        backup="${DOCKER_DAEMON}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$DOCKER_DAEMON" "$backup"
        log_info "已备份现有配置到: $backup"
    fi
    local existing_mirrors
    existing_mirrors=$(get_current_mirrors)
    local new_mirrors=""
    if [[ -n "$existing_mirrors" ]]; then
        new_mirrors="${existing_mirrors} https://${mirror}"
    else
        new_mirrors="https://${mirror}"
    fi
    cat > "$DOCKER_DAEMON" <<EOF
{
  "registry-mirrors": [$(echo "$new_mirrors" | tr ' ' '\n' | sed "s/^/\"/;s/$/\",/" | tr -d '\n' | sed 's/,$//')]
}
EOF
    log_info "已写入镜像配置: $DOCKER_DAEMON"
}

select_mirror() {
    echo ""
    echo -e "${BOLD}请选择镜像源:${NC}"
    for i in "${!MIRROR_SOURCES[@]}"; do
        echo "  $((i+1))) ${MIRROR_SOURCES[$i]}"
    done
    echo "  0) 手动输入"
    echo ""
    while true; do
        read -p "请输入选项 [1]: " choice
        choice="${choice:-1}"
        if [[ "$choice" == "0" ]]; then
            read -p "请输入镜像源地址: " custom_mirror
            if [[ -n "$custom_mirror" ]]; then
                [[ "$custom_mirror" != https://* ]] && custom_mirror="https://${custom_mirror}"
                echo "$custom_mirror"
                return 0
            fi
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#MIRROR_SOURCES[@]}" ]]; then
            echo "https://${MIRROR_SOURCES[$((choice-1))]}"
            return 0
        else
            echo -e "${RED}无效选择，请重试${NC}"
        fi
    done
}

test_mirror_speed() {
    local mirror="$1"
    local start end elapsed
    start=$(date +%s%N)
    if curl -sf --connect-timeout 5 --max-time 30 "https://${mirror}" &>/dev/null; then
        end=$(date +%s%N)
        elapsed=$(( (end - start) / 1000000 ))
        echo "$elapsed"
        return 0
    fi
    echo "timeout"
    return 1
}

main() {
    echo ""
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}  Docker 镜像加速配置工具${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo ""
    log_info "检测网络环境..."
    if is_cn_network; then
        log_info "检测到中国大陆网络环境"
    else
        log_warn "未检测到中国大陆特征"
        read -p "是否继续配置镜像加速? [y/N]: " confirm
        confirm="${confirm:-n}"
        [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]] && exit 0
    fi
    local current
    current=$(get_current_mirrors)
    [[ -n "$current" ]] && log_info "当前已配置镜像: $current"
    echo ""
    echo -e "${BOLD}镜像源速度测试:${NC}"
    local fastest_mirror=""
    local fastest_time=999999
    for source in "${MIRROR_SOURCES[@]}"; do
        printf "  测试 %-30s ... " "$source"
        local t
        t=$(test_mirror_speed "$source")
        if [[ "$t" != "timeout" ]]; then
            echo -e "${GREEN}${t}ms${NC}"
            [[ "$t" -lt "$fastest_time" ]] && fastest_time=$t && fastest_mirror="$source"
        else
            echo -e "${RED}超时${NC}"
        fi
    done
    echo ""
    echo -e "推荐镜像源: ${GREEN}${fastest_mirror}${NC} (${fastest_time}ms)"
    echo ""
    read -p "是否使用推荐的镜像源? [Y/n]: " use_recommend
    use_recommend="${use_recommend:-y}"
    local selected_mirror
    if [[ "$use_recommend" == "y" ]] || [[ "$use_recommend" == "Y" ]]; then
        selected_mirror="https://${fastest_mirror}"
    else
        selected_mirror=$(select_mirror)
    fi
    log_info "正在配置 Docker 镜像加速..."
    write_mirror_config "${selected_mirror#https://}"
    echo ""
    log_warn "需要重启 Docker 守护进程以使配置生效"
    if command -v systemctl &>/dev/null; then
        echo "  运行: sudo systemctl restart docker"
    elif command -v service &>/dev/null; then
        echo "  运行: sudo service docker restart"
    fi
    echo ""
    read -p "是否现在验证配置? [y/N]: " verify
    verify="${verify:-n}"
    if [[ "$verify" == "y" ]] || [[ "$verify" == "Y" ]]; then
        verify_docker_pull && log_info "镜像加速配置成功!" || log_error "配置可能未生效"
    fi
    echo ""
    log_info "配置完成!"
}
main "$@"
