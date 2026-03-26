#!/bin/bash
# =============================================================================
# fix-dns-port.sh — 处理 systemd-resolved 53 端口冲突
# =============================================================================
# 功能：检测并禁用 systemd-resolved 对 53 端口的占用
# 支持：--check（检测）、--apply（应用）、--restore（还原）
# 适用：Ubuntu/Debian 等使用 systemd-resolved 的系统
# =============================================================================

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

RESOLVED_CONF="/etc/systemd/resolved.conf"
RESOLVED_STUB="/run/systemd/resolve/stub-resolv.conf"
RESOLVED_MANAGED="/run/systemd/resolve/resolv.conf"
DNS_STUB_BACKUP="/run/systemd/resolve/stub-resolv.conf.bak"
SYSTEMD_RESOLVED_SERVICE="systemd-resolved"

# -----------------------------------------------------------------------------
# 辅助函数
# -----------------------------------------------------------------------------
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查是否以 root 身份运行
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行。请使用 sudo 或以 root 用户执行。"
        exit 1
    fi
}

# 检查 systemd-resolved 是否在运行
is_resolved_running() {
    systemctl is-active --quiet "$SYSTEMD_RESOLVED_SERVICE" 2>/dev/null
}

# 检查 53 端口是否被 systemd-resolved 占用
check_53_port() {
    log_info "检查 53 端口占用情况..."

    # 方法1：检查 stub-resolv.conf（最常见标志）
    if [[ -L "$RESOLVED_STUB" ]] && grep -q "127.0.0.53" "$RESOLVED_STUB" 2>/dev/null; then
        log_warn "检测到 systemd-resolved stub resolver（127.0.0.53）正在占用 DNS 53 端口"
        return 0
    fi

    # 方法2：检查哪个进程在监听 53 端口
    if command -v ss &>/dev/null; then
        if ss -tulnp | grep -q ':53 ' 2>/dev/null; then
            log_warn "53 端口当前被占用，正在分析..."
            ss -tulnp | grep ':53 ' || true
            return 0
        fi
    elif command -v netstat &>/dev/null; then
        if netstat -tulnp | grep -q ':53 ' 2>/dev/null; then
            log_warn "53 端口当前被占用"
            return 0
        fi
    fi

    # 方法3：检查 resolved.conf 的 DNSStubListener
    if [[ -f "$RESOLVED_CONF" ]] && grep -q "DNSStubListener=yes" "$RESOLVED_CONF" 2>/dev/null; then
        log_warn "DNSStubListener=yes 配置存在，systemd-resolved 可能占用 53 端口"
        return 0
    fi

    log_info "53 端口未被 systemd-resolved 占用（或已处理）"
    return 1
}

# 应用修复：禁用 systemd-resolved 的 DNS Stub Listener
apply_fix() {
    log_info "正在应用修复..."

    # 备份原配置
    if [[ -f "$RESOLVED_CONF" ]]; then
        cp "$RESOLVED_CONF" "${RESOLVED_CONF}.bak.$(date +%Y%m%d%H%M%S)"
        log_info "已备份 ${RESOLVED_CONF}"
    fi

    # 检查是否已经有 DNSStubListener=no
    if grep -q "DNSStubListener=no" "$RESOLVED_CONF" 2>/dev/null; then
        log_info "DNSStubListener 已设为 no，跳过"
    elif grep -q "DNSStubListener=yes" "$RESOLVED_CONF" 2>/dev/null; then
        sed -i 's/DNSStubListener=yes/DNSStubListener=no/' "$RESOLVED_CONF"
        log_info "已将 DNSStubListener=yes 改为 DNSStubListener=no"
    else
        # 在 [Resolve] section 添加
        if grep -q "^\[Resolve\]" "$RESOLVED_CONF" 2>/dev/null; then
            sed -i '/^\[Resolve\]/a DNSStubListener=no' "$RESOLVED_CONF"
        else
            echo -e "\n[Resolve]\nDNSStubListener=no" >> "$RESOLVED_CONF"
        fi
        log_info "已在 ${RESOLVED_CONF} 添加 DNSStubListener=no"
    fi

    # 备份 stub-resolv.conf 并创建指向真实 resolv.conf 的链接
    if [[ -f "$RESOLVED_STUB" ]] && [[ ! -f "$DNS_STUB_BACKUP" ]]; then
        cp "$RESOLVED_STUB" "$DNS_STUB_BACKUP"
        log_info "已备份 stub-resolv.conf"
    fi

    # 让 resolv.conf 指向真实的 resolv.conf
    if [[ -f "$RESOLVED_MANAGED" ]]; then
        ln -sf "$RESOLVED_MANAGED" "$RESOLVED_STUB"
        log_info "已让 stub-resolv.conf 指向真实 resolv.conf"
    fi

    # 重启 systemd-resolved 使配置生效
    if is_resolved_running; then
        log_info "重启 systemd-resolved 服务..."
        systemctl restart "$SYSTEMD_RESOLVED_SERVICE"
        sleep 2
        log_info "systemd-resolved 已重启"
    fi

    # 验证 53 端口是否释放
    log_info "验证 53 端口状态..."
    sleep 2
    if command -v ss &>/dev/null; then
        local port_info
        port_info=$(ss -tulnp | grep ':53 ' 2>/dev/null || echo "")
        if [[ -z "$port_info" ]]; then
            log_info "${GREEN}✓ 53 端口已释放，修复成功！${NC}"
        else
            log_warn "53 端口可能仍被占用，请检查："
            echo "$port_info"
        fi
    fi

    log_info "${GREEN}修复完成！${NC}"
    log_info "后续步骤："
    log_info "  1. 确保 Docker 可以绑定 53 端口：sudo setcap 'cap_net_bind_service=+ep' \$(which dockerd)"
    log_info "  2. 启动 AdGuard Home：docker compose -f stacks/network/docker-compose.yml up -d"
    log_info "  3. 如需还原，请运行：$0 --restore"
}

# 还原修复
restore() {
    log_info "正在还原配置..."

    # 还原 resolved.conf
    local latest_bak
    latest_bak=$(ls -t "${RESOLVED_CONF}".bak.* 2>/dev/null | head -1)
    if [[ -n "$latest_bak" ]]; then
        cp "$latest_bak" "$RESOLVED_CONF"
        rm "$latest_bak"
        log_info "已还原 ${RESOLVED_CONF}"
    else
        # 手动还原 DNSStubListener
        if [[ -f "$RESOLVED_CONF" ]]; then
            sed -i 's/DNSStubListener=no/DNSStubListener=yes/' "$RESOLVED_CONF"
            log_info "已将 DNSStubListener 还原为 yes"
        fi
    fi

    # 还原 stub-resolv.conf
    if [[ -f "$DNS_STUB_BACKUP" ]]; then
        cp "$DNS_STUB_BACKUP" "$RESOLVED_STUB"
        rm "$DNS_STUB_BACKUP"
        log_info "已还原 stub-resolv.conf"
    fi

    # 重启 systemd-resolved
    if is_resolved_running; then
        log_info "重启 systemd-resolved 服务..."
        systemctl restart "$SYSTEMD_RESOLVED_SERVICE"
        sleep 2
    fi

    log_info "${GREEN}还原完成！${NC}"
}

# -----------------------------------------------------------------------------
# 主逻辑
# -----------------------------------------------------------------------------
show_help() {
    cat << EOF
fix-dns-port.sh — 修复 systemd-resolved 的 53 端口冲突

用法：sudo $0 [选项]

选项：
  --check    检测 systemd-resolved 是否占用 53 端口（默认）
  --apply    禁用 systemd-resolved 的 DNS Stub Listener 并释放 53 端口
  --restore  还原 systemd-resolved 配置
  --help     显示此帮助信息

示例：
  sudo $0 --check      # 检查 53 端口占用
  sudo $0 --apply      # 应用修复，释放 53 端口
  sudo $0 --restore    # 还原原始配置

注意：
  - 必须使用 root 权限运行（sudo）
  - 此脚本仅适用于使用 systemd-resolved 的 Linux 发行版
  - 修改 DNS 配置可能影响系统 DNS 解析，请谨慎操作
EOF
}

main() {
    case "${1:-}" in
        --check)
            check_root
            if check_53_port; then
                log_warn "检测到 53 端口被 systemd-resolved 占用"
                echo ""
                log_info "运行 '$0 --apply' 可以自动修复此问题"
                exit 1
            else
                log_info "53 端口未被 systemd-resolved 占用"
                exit 0
            fi
            ;;
        --apply)
            check_root
            check_53_port || true
            apply_fix
            ;;
        --restore)
            check_root
            restore
            ;;
        --help|-h)
            show_help
            ;;
        "")
            # 默认行为同 --check
            check_root
            check_53_port || true
            ;;
        *)
            log_error "未知参数：$1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
