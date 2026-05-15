#!/usr/bin/env bash
# =============================================================================
# HomeLab Stack — DNS Port Conflict Fix
# Detects and resolves systemd-resolved port 53 conflict for AdGuard Home
#
# Usage:
#   ./scripts/fix-dns-port.sh --check    # Check if port 53 is in use
#   ./scripts/fix-dns-port.sh --apply    # Disable systemd-resolved on port 53
#   ./scripts/fix-dns-port.sh --restore  # Restore original configuration
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_pass()  { echo -e "${GREEN}[PASS]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ---------------------------------------------------------------------------
# Backup directory
# ---------------------------------------------------------------------------
BACKUP_DIR="/var/backups/homelab-dns-fix"
mkdir -p "$BACKUP_DIR" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Check: Is port 53 in use?
# ---------------------------------------------------------------------------
check_port_53() {
    echo -e "\n${BLUE}=== Checking port 53 usage ===${NC}\n"

    local found=false

    # Check with ss
    if command -v ss &>/dev/null; then
        local ss_output
        ss_output=$(ss -tlnp 2>/dev/null | grep ':53 ' || true)
        if [[ -n "$ss_output" ]]; then
            log_warn "Port 53 is in use (ss):"
            echo "$ss_output"
            found=true
        fi
    fi

    # Check with netstat
    if command -v netstat &>/dev/null; then
        local netstat_output
        netstat_output=$(netstat -tlnp 2>/dev/null | grep ':53 ' || true)
        if [[ -n "$netstat_output" ]]; then
            log_warn "Port 53 is in use (netstat):"
            echo "$netstat_output"
            found=true
        fi
    fi

    # Check systemd-resolved status
    if systemctl is-active systemd-resolved &>/dev/null; then
        log_warn "systemd-resolved is running"
        found=true

        # Show DNSStubListener status
        if [[ -f /etc/systemd/resolved.conf ]]; then
            local listen
            listen=$(grep -i "^DNSStubListener=" /etc/systemd/resolved.conf 2>/dev/null || true)
            if [[ -n "$listen" ]]; then
                log_info "Current setting: $listen"
            else
                log_info "DNSStubListener not explicitly set (defaults to 'yes')"
            fi
        fi
    fi

    if [[ "$found" == "false" ]]; then
        log_pass "Port 53 is free — no conflict detected"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Apply: Disable systemd-resolved on port 53
# ---------------------------------------------------------------------------
apply_fix() {
    echo -e "\n${BLUE}=== Applying DNS port fix ===${NC}\n"

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi

    # Method 1: Disable DNSStubListener in systemd-resolved
    if [[ -f /etc/systemd/resolved.conf ]]; then
        # Backup original
        local backup_file="$BACKUP_DIR/resolved.conf.bak.$(date +%Y%m%d%H%M%S)"
        cp /etc/systemd/resolved.conf "$backup_file"
        log_info "Backed up: $backup_file"

        # Check if already configured
        if grep -q "^DNSStubListener=no" /etc/systemd/resolved.conf 2>/dev/null; then
            log_info "DNSStubListener already set to 'no'"
        else
            # Apply the fix
            if grep -q "^\[Resolve\]" /etc/systemd/resolved.conf; then
                # Add under [Resolve] section
                sed -i '/^\[Resolve\]/a DNSStubListener=no' /etc/systemd/resolved.conf
            else
                # Append section and setting
                echo -e "\n[Resolve]\nDNSStubListener=no" >> /etc/systemd/resolved.conf
            fi
            log_pass "Set DNSStubListener=no in /etc/systemd/resolved.conf"
        fi

        # Update resolv.conf symlink
        if [[ -L /etc/resolv.conf ]]; then
            local target
            target=$(readlink /etc/resolv.conf)
            if [[ "$target" == *"systemd/resolv.conf"* ]]; then
                # Backup current symlink
                cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf.bak.$(date +%Y%m%d%H%M%S)"
                # Remove symlink and point to systemd-resolved's stub
                rm /etc/resolv.conf
                ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
                log_pass "Updated /etc/resolv.conf symlink"
            fi
        fi

        # Restart systemd-resolved
        systemctl restart systemd-resolved
        log_pass "Restarted systemd-resolved"

        # Verify
        sleep 2
        if ss -tlnp 2>/dev/null | grep -q ':53 '; then
            log_warn "Port 53 still in use — may need manual intervention"
            log_info "Try: sudo systemctl stop systemd-resolved"
        else
            log_pass "Port 53 is now free"
        fi
    else
        log_warn "/etc/systemd/resolved.conf not found"
        log_info "systemd-resolved may not be installed — port 53 should be free"
    fi

    # Disable systemd-resolved if still binding port 53
    if ss -tlnp 2>/dev/null | grep -q ':53 '; then
        log_warn "Port 53 still occupied after config change"
        log_info "Attempting to stop systemd-resolved..."
        systemctl stop systemd-resolved
        systemctl disable systemd-resolved
        log_pass "Stopped and disabled systemd-resolved"

        # Create static resolv.conf
        rm -f /etc/resolv.conf
        cat > /etc/resolv.conf <<'EOF'
# HomeLab DNS Configuration
# Managed by homelab-stack network stack
nameserver 127.0.0.1
nameserver 1.1.1.1
options edns0
EOF
        log_pass "Created static /etc/resolv.conf pointing to 127.0.0.1"
    fi

    echo
    log_pass "DNS port fix applied successfully"
    log_info "You can now start the network stack: docker compose up -d"
}

# ---------------------------------------------------------------------------
# Restore: Undo the fix
# ---------------------------------------------------------------------------
restore_original() {
    echo -e "\n${BLUE}=== Restoring original DNS configuration ===${NC}\n"

    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi

    # Restore resolved.conf
    local latest_backup
    latest_backup=$(ls -t "$BACKUP_DIR"/resolved.conf.bak.* 2>/dev/null | head -1)
    if [[ -n "$latest_backup" ]]; then
        cp "$latest_backup" /etc/systemd/resolved.conf
        log_pass "Restored /etc/systemd/resolved.conf from $latest_backup"
    else
        log_warn "No resolved.conf backup found"
        # Reset to defaults
        if [[ -f /etc/systemd/resolved.conf ]]; then
            sed -i '/^DNSStubListener=/d' /etc/systemd/resolved.conf
            log_info "Removed DNSStubListener line from resolved.conf"
        fi
    fi

    # Restore resolv.conf
    local latest_resolv
    latest_resolv=$(ls -t "$BACKUP_DIR"/resolv.conf.bak.* 2>/dev/null | head -1)
    if [[ -n "$latest_resolv" ]]; then
        cp "$latest_resolv" /etc/resolv.conf
        log_pass "Restored /etc/resolv.conf from $latest_resolv"
    else
        log_warn "No resolv.conf backup found"
        # Recreate symlink
        rm -f /etc/resolv.conf
        ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        log_info "Recreated default resolv.conf symlink"
    fi

    # Re-enable and restart systemd-resolved
    systemctl enable systemd-resolved 2>/dev/null || true
    systemctl start systemd-resolved 2>/dev/null || true
    log_pass "Re-enabled and started systemd-resolved"

    echo
    log_pass "Original DNS configuration restored"
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    echo "Usage: $0 [--check|--apply|--restore]"
    echo
    echo "  --check     Check if port 53 is in use"
    echo "  --apply     Disable systemd-resolved port 53 binding"
    echo "  --restore   Restore original DNS configuration"
    echo
    echo "Examples:"
    echo "  $0 --check                  # Just check, no changes"
    echo "  sudo $0 --apply             # Apply the fix"
    echo "  sudo $0 --restore           # Undo the fix"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
case "${1:-}" in
    --check|-c)
        check_port_53
        ;;
    --apply|-a)
        apply_fix
        ;;
    --restore|-r)
        restore_original
        ;;
    --help|-h)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
