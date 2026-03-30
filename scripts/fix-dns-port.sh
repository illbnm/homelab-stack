#!/bin/bash
# fix-dns-port.sh - 处理 systemd-resolved 与 AdGuard Home 的 53 端口冲突

set -e

ACTION="${1:-check}"
RESOLVED_CONF="/etc/systemd/resolved.conf"
BACKUP_SUFFIX=".backup.$(date +%s)"

check_dns_conflict() {
    echo "🔍 检查 DNS 端口冲突..."
    
    if sudo lsof -i :53 2>/dev/null | grep -q systemd-resolved; then
        echo "⚠️  systemd-resolved 正在占用 53 端口"
        return 1
    else
        echo "✅ 53 端口未被占用"
        return 0
    fi
}

disable_resolved() {
    echo "🛑 禁用 systemd-resolved..."
    
    # 备份原配置
    if [ -f "$RESOLVED_CONF" ]; then
        sudo cp "$RESOLVED_CONF" "$RESOLVED_CONF$BACKUP_SUFFIX"
        echo "📦 备份到: $RESOLVED_CONF$BACKUP_SUFFIX"
    fi
    
    # 禁用 systemd-resolved
    sudo systemctl stop systemd-resolved
    sudo systemctl disable systemd-resolved
    
    # 更新 /etc/resolv.conf
    echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf > /dev/null
    
    echo "✅ systemd-resolved 已禁用"
}

restore_resolved() {
    echo "🔄 恢复 systemd-resolved..."
    
    # 找最新的备份
    LATEST_BACKUP=$(ls -t "$RESOLVED_CONF"* 2>/dev/null | head -1)
    
    if [ -n "$LATEST_BACKUP" ]; then
        sudo cp "$LATEST_BACKUP" "$RESOLVED_CONF"
        echo "📦 从备份恢复: $LATEST_BACKUP"
    fi
    
    # 重启 systemd-resolved
    sudo systemctl enable systemd-resolved
    sudo systemctl start systemd-resolved
    
    echo "✅ systemd-resolved 已恢复"
}

case "$ACTION" in
    check)
        check_dns_conflict
        ;;
    apply)
        check_dns_conflict || disable_resolved
        ;;
    restore)
        restore_resolved
        ;;
    *)
        echo "用法: $0 {check|apply|restore}"
        echo "  check   - 检查 DNS 端口冲突"
        echo "  apply   - 禁用 systemd-resolved"
        echo "  restore - 恢复 systemd-resolved"
        exit 1
        ;;
esac
