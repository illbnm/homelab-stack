#!/bin/bash
# Fix systemd-resolved 53 port conflict
# Usage: ./fix-dns-port.sh {--check|--apply|--restore}

set -e

case "$1" in
    --check)
        echo "🔍 Checking systemd-resolved status..."
        echo ""
        echo "=== Service Status ==="
        systemctl status systemd-resolved --no-pager || true
        echo ""
        echo "=== Port 53 Usage ==="
        sudo ss -tulnp | grep :53 || echo "Port 53 not in use"
        echo ""
        echo "=== Resolved Config ==="
        cat /etc/systemd/resolved.conf | grep -v "^#" | grep -v "^$" || echo "Default config"
        ;;
    
    --apply)
        echo "🔧 Disabling systemd-resolved DNS stub listener..."
        echo ""
        
        # Backup original config
        sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.backup
        
        # Update config
        sudo tee /etc/systemd/resolved.conf > /dev/null <<EOF
[Resolve]
DNS=127.0.0.1#54
DNSStubListener=no
EOF
        
        # Restart service
        sudo systemctl restart systemd-resolved
        
        echo "✅ Done! systemd-resolved now uses port 54"
        echo "📝 AdGuard Home can now bind to port 53"
        echo ""
        echo "To restore original config, run: $0 --restore"
        ;;
    
    --restore)
        echo "🔄 Restoring systemd-resolved..."
        
        if [ -f /etc/systemd/resolved.conf.backup ]; then
            sudo mv /etc/systemd/resolved.conf.backup /etc/systemd/resolved.conf
            sudo systemctl restart systemd-resolved
            echo "✅ Restored to original configuration!"
        else
            echo "⚠️  No backup found. Resetting to defaults..."
            sudo sed -i 's/DNSStubListener=no/DNSStubListener=yes/' /etc/systemd/resolved.conf
            sudo systemctl restart systemd-resolved
            echo "✅ Reset to defaults!"
        fi
        ;;
    
    *)
        echo "Usage: $0 {--check|--apply|--restore}"
        echo ""
        echo "Commands:"
        echo "  --check   Check current DNS configuration and port usage"
        echo "  --apply   Disable systemd-resolved stub listener (free port 53)"
        echo "  --restore Restore original systemd-resolved configuration"
        exit 1
        ;;
esac
