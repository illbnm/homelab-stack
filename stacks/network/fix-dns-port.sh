#!/bin/bash
# fix-dns-port.sh - 检测并禁用 systemd-resolved 的 53 端口占用
# 支持 --check, --apply, --restore

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 帮助信息
usage() {
    cat << EOF
用法: $0 [选项]

选项:
    --check     检查 systemd-resolved 状态和端口占用情况
    --apply     禁用 systemd-resolved 的 DNS stub 监听器
    --restore   恢复 systemd-resolved 的默认配置
    --help      显示此帮助信息

示例:
    $0 --check
    $0 --apply
    $0 --restore

说明:
    此脚本用于解决 AdGuard Home 等 DNS 服务与 systemd-resolved 的端口冲突。
    systemd-resolved 默认监听 53 端口，会阻止其他 DNS 服务绑定该端口。
EOF
}

# 检查 systemd-resolved 状态
check_resolved() {
    echo -e "${YELLOW}检查 systemd-resolved 状态...${NC}"
    
    # 检查服务是否运行
    if systemctl is-active --quiet systemd-resolved; then
        echo -e "  ${GREEN}✓ systemd-resolved 正在运行${NC}"
    else
        echo -e "  ${YELLOW}⚠ systemd-resolved 未运行${NC}"
    fi
    
    # 检查端口占用
    echo -e "${YELLOW}检查 53 端口占用情况...${NC}"
    if ss -lpn | grep -E ':53\b' > /dev/null; then
        echo -e "  ${RED}✗ 53 端口已被占用:${NC}"
        ss -lpn | grep -E ':53\b'
    else
        echo -e "  ${GREEN}✓ 53 端口未被占用${NC}"
    fi
    
    # 检查 DNSStubListener 配置
    echo -e "${YELLOW}检查 DNSStubListener 配置...${NC}"
    if [ -f /etc/systemd/resolved.conf ]; then
        if grep -q "^#\?DNSStubListener=no" /etc/systemd/resolved.conf; then
            echo -e "  ${GREEN}✓ DNSStubListener 已禁用${NC}"
        elif grep -q "^DNSStubListener=yes" /etc/systemd/resolved.conf; then
            echo -e "  ${RED}✗ DNSStubListener 已启用${NC}"
        else
            echo -e "  ${YELLOW}⚠ DNSStubListener 使用默认值 (启用)${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠ /etc/systemd/resolved.conf 不存在${NC}"
    fi
    
    # 检查当前 DNS 配置
    echo -e "${YELLOW}检查当前 DNS 配置...${NC}"
    cat /etc/resolv.conf | head -5
}

# 禁用 systemd-resolved 的 DNS stub 监听器
apply_fix() {
    echo -e "${YELLOW}禁用 systemd-resolved 的 DNS stub 监听器...${NC}"
    
    # 备份原始配置
    if [ ! -f /etc/systemd/resolved.conf.backup ]; then
        cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.backup 2>/dev/null || true
        echo -e "  ${GREEN}✓ 备份原始配置${NC}"
    fi
    
    # 创建或修改 resolved.conf
    cat > /etc/systemd/resolved.conf << EOF
# 由 fix-dns-port.sh 修改
# 禁用 DNS stub 监听器以释放 53 端口
[Resolve]
DNSStubListener=no
# 使用备用 DNS 服务器
DNS=1.1.1.1 8.8.8.8
FallbackDNS=1.0.0.1 8.8.4.4
# 启用 DNSSEC
DNSSEC=allow-downgrade
EOF
    
    echo -e "  ${GREEN}✓ 更新 /etc/systemd/resolved.conf${NC}"
    
    # 重启 systemd-resolved
    systemctl restart systemd-resolved
    echo -e "  ${GREEN}✓ 重启 systemd-resolved 服务${NC}"
    
    # 更新 /etc/resolv.conf
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf 2>/dev/null || true
    echo -e "  ${GREEN}✓ 更新 /etc/resolv.conf 符号链接${NC}"
    
    # 验证更改
    echo -e "${YELLOW}验证更改...${NC}"
    sleep 2
    if ss -lpn | grep -E ':53\b' | grep -v systemd-resolved > /dev/null; then
        echo -e "  ${RED}✗ 53 端口仍被占用${NC}"
        ss -lpn | grep -E ':53\b'
    else
        echo -e "  ${GREEN}✓ 53 端口已释放${NC}"
    fi
    
    echo -e "\n${GREEN}✅ 修复完成！${NC}"
    echo -e "现在可以启动 AdGuard Home 或其他 DNS 服务。"
}

# 恢复原始配置
restore_config() {
    echo -e "${YELLOW}恢复 systemd-resolved 原始配置...${NC}"
    
    if [ -f /etc/systemd/resolved.conf.backup ]; then
        cp /etc/systemd/resolved.conf.backup /etc/systemd/resolved.conf
        echo -e "  ${GREEN}✓ 恢复原始配置${NC}"
    else
        # 恢复默认配置
        cat > /etc/systemd/resolved.conf << EOF
# 恢复默认配置
[Resolve]
#DNS=
#FallbackDNS=
#DNSSEC=
#DNSOverTLS=
#DNSStubListener=yes
#ReadEtcHosts=yes
EOF
        echo -e "  ${YELLOW}⚠ 使用默认配置 (备份不存在)${NC}"
    fi
    
    # 重启 systemd-resolved
    systemctl restart systemd-resolved
    echo -e "  ${GREEN}✓ 重启 systemd-resolved 服务${NC}"
    
    # 恢复 /etc/resolv.conf
    if [ -f /etc/resolv.conf.backup ]; then
        cp /etc/resolv.conf.backup /etc/resolv.conf
        echo -e "  ${GREEN}✓ 恢复原始 /etc/resolv.conf${NC}"
    fi
    
    echo -e "\n${GREEN}✅ 配置已恢复！${NC}"
}

# 主逻辑
main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi
    
    case "$1" in
        --check)
            check_resolved
            ;;
        --apply)
            apply_fix
            ;;
        --restore)
            restore_config
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}错误: 未知选项 '$1'${NC}"
            usage
            exit 1
            ;;
    esac
}

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误: 此脚本需要 root 权限${NC}"
    echo -e "请使用 sudo 运行: sudo $0 $@"
    exit 1
fi

# 执行主函数
main "$@"