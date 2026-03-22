#!/bin/bash
# =============================================================================
# fix-dns-port.sh — Free Port 53 from systemd-resolved
# 
# AdGuard Home requires port 53, but systemd-resolved often occupies it.
# This script detects and resolves the conflict.
#
# Usage:
#   ./fix-dns-port.sh --check    # Check if port 53 is occupied
#   ./fix-dns-port.sh --apply    # Apply fix (disable systemd-resolved DNS)
#   ./fix-dns-port.sh --restore  # Restore systemd-resolved to default
#   ./fix-dns-port.sh --status   # Show current DNS configuration
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

RESOLVED_CONF="/etc/systemd/resolved.conf"
RESOLVED_CONF_BACKUP="/etc/systemd/resolved.conf.backup"
BACKUP_DIR="/etc/systemd/resolved.conf.d"

# Print colored message
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check what's using port 53
check_port_53() {
    print_info "Checking port 53 usage..."
    
    if command -v ss &> /dev/null; then
        SS_OUTPUT=$(ss -tulnp | grep ':53' || true)
        if [[ -n "$SS_OUTPUT" ]]; then
            print_warning "Port 53 is currently in use:"
            echo "$SS_OUTPUT"
            return 0
        fi
    elif command -v netstat &> /dev/null; then
        NETSTAT_OUTPUT=$(netstat -tulnp | grep ':53' || true)
        if [[ -n "$NETSTAT_OUTPUT" ]]; then
            print_warning "Port 53 is currently in use:"
            echo "$NETSTAT_OUTPUT"
            return 0
        fi
    fi
    
    print_success "Port 53 is currently free"
    return 1
}

# Check systemd-resolved status
check_resolved_status() {
    print_info "Checking systemd-resolved status..."
    
    if systemctl is-active --quiet systemd-resolved; then
        print_info "systemd-resolved is active"
        
        # Check current DNS settings
        if [[ -f "$RESOLVED_CONF" ]]; then
            DNS_LINE=$(grep -E "^DNS=" "$RESOLVED_CONF" || true)
            if [[ -n "$DNS_LINE" ]]; then
                print_info "Current DNS setting: $DNS_LINE"
            fi
        fi
        
        return 0
    else
        print_info "systemd-resolved is not active"
        return 1
    fi
}

# Apply fix: Move systemd-resolved to port 5353
apply_fix() {
    print_info "Applying fix to free port 53..."
    
    # Create backup directory
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        print_info "Created backup directory: $BACKUP_DIR"
    fi
    
    # Create override configuration
    cat > "$BACKUP_DIR/53-port.conf" << 'EOF'
[Resolve]
# Move systemd-resolved to port 5353 to free port 53 for AdGuard Home
DNSStubListenerExtra=5353
EOF
    
    print_info "Created override configuration: $BACKUP_DIR/53-port.conf"
    
    # Backup original config if exists
    if [[ -f "$RESOLVED_CONF" ]] && [[ ! -f "$RESOLVED_CONF_BACKUP" ]]; then
        cp "$RESOLVED_CONF" "$RESOLVED_CONF_BACKUP"
        print_info "Backed up original config to: $RESOLVED_CONF_BACKUP"
    fi
    
    # Update main resolved.conf
    if [[ -f "$RESOLVED_CONF" ]]; then
        # Remove existing DNSStubListenerExtra lines
        sed -i '/^DNSStubListenerExtra/d' "$RESOLVED_CONF"
        
        # Add DNSStubListenerExtra if not exists
        if ! grep -q "^DNSStubListenerExtra=" "$RESOLVED_CONF"; then
            echo "DNSStubListenerExtra=5353" >> "$RESOLVED_CONF"
        fi
    fi
    
    # Restart systemd-resolved
    print_info "Restarting systemd-resolved..."
    systemctl restart systemd-resolved
    
    # Verify port 53 is now free
    sleep 2
    if check_port_53; then
        print_warning "Port 53 is still occupied. Manual intervention may be required."
        print_info "Try: sudo systemctl stop systemd-resolved && sudo systemctl disable systemd-resolved"
    else
        print_success "Port 53 has been freed!"
        print_info "AdGuard Home can now bind to port 53"
    fi
    
    print_info "Note: systemd-resolved is now listening on port 5353"
    print_info "To restore original configuration, run: $0 --restore"
}

# Restore original configuration
restore_config() {
    print_info "Restoring original systemd-resolved configuration..."
    
    # Remove override
    if [[ -f "$BACKUP_DIR/53-port.conf" ]]; then
        rm -f "$BACKUP_DIR/53-port.conf"
        print_info "Removed override configuration"
    fi
    
    # Restore backup if exists
    if [[ -f "$RESOLVED_CONF_BACKUP" ]]; then
        mv "$RESOLVED_CONF_BACKUP" "$RESOLVED_CONF"
        print_info "Restored original configuration from backup"
    else
        # Remove DNSStubListenerExtra from current config
        if [[ -f "$RESOLVED_CONF" ]]; then
            sed -i '/^DNSStubListenerExtra/d' "$RESOLVED_CONF"
            print_info "Removed DNSStubListenerExtra from configuration"
        fi
    fi
    
    # Restart systemd-resolved
    print_info "Restarting systemd-resolved..."
    systemctl restart systemd-resolved
    
    print_success "Configuration restored to default"
}

# Show current status
show_status() {
    print_info "=== DNS Configuration Status ==="
    echo ""
    
    # systemd-resolved status
    if systemctl is-active --quiet systemd-resolved; then
        print_success "systemd-resolved: active"
    else
        print_warning "systemd-resolved: inactive"
    fi
    
    # Port 53 status
    echo ""
    print_info "Port 53 status:"
    check_port_53 || true
    
    # Port 5353 status
    echo ""
    print_info "Port 5353 status:"
    if command -v ss &> /dev/null; then
        ss -tulnp | grep ':5353' || print_info "Port 5353 is free"
    fi
    
    # Current DNS servers
    echo ""
    print_info "Current DNS servers (from resolv.conf):"
    if [[ -f /etc/resolv.conf ]]; then
        grep -E "^nameserver" /etc/resolv.conf || print_info "No nameservers configured"
    fi
    
    # AdGuard Home readiness
    echo ""
    if ! check_port_53; then
        print_success "✓ System is ready for AdGuard Home installation"
    else
        print_warning "✗ Port 53 conflict detected - run '$0 --apply' to fix"
    fi
}

# Show help
show_help() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --check    Check if port 53 is occupied by systemd-resolved"
    echo "  --apply    Apply fix to free port 53 (move systemd-resolved to 5353)"
    echo "  --restore  Restore original systemd-resolved configuration"
    echo "  --status   Show current DNS and port configuration"
    echo "  --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  sudo $0 --check    # Check port 53 status"
    echo "  sudo $0 --apply    # Apply the fix"
    echo "  sudo $0 --restore  # Undo the fix"
}

# Main
main() {
    case "${1:-}" in
        --check)
            check_root
            check_port_53
            check_resolved_status
            ;;
        --apply)
            check_root
            apply_fix
            ;;
        --restore)
            check_root
            restore_config
            ;;
        --status)
            show_status
            ;;
        --help|-h)
            show_help
            ;;
        *)
            print_error "Invalid option: ${1:-}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
