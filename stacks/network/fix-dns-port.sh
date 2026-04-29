#!/usr/bin/env bash
# =============================================================================
# fix-dns-port.sh — Handle systemd-resolved port 53 conflict
#
# On many Linux distros, systemd-resolved listens on 127.0.0.53:53,
# preventing AdGuard Home from binding to port 53.
#
# Usage:
#   ./fix-dns-port.sh --check     # Check if port 53 is occupied
#   ./fix-dns-port.sh --apply     # Disable systemd-resolved stub listener
#   ./fix-dns-port.sh --restore   # Re-enable systemd-resolved stub listener
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
log_ok()   { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_err()  { echo -e "${RED}[ERR]${RESET} $*" >&2; }

RESOLVED_CONF="/etc/systemd/resolved.conf"
BACKUP="/etc/systemd/resolved.conf.bak"

check_port_53() {
    local occupier
    occupier=$(ss -ulnp 'sport = :53' 2>/dev/null | grep -oP 'users:\(\("\K[^"]+' | head -1 || true)
    if [ -n "$occupier" ]; then
        log_warn "Port 53/UDP is occupied by: $occupier"
        return 1
    else
        log_ok "Port 53/UDP is free"
        return 0
    fi
}

check_systemd_resolved() {
    if systemctl is-active systemd-resolved &>/dev/null; then
        log_warn "systemd-resolved is running"
        local stub
        stub=$(grep -E '^DNSStubListener=' "$RESOLVED_CONF" 2>/dev/null | cut -d= -f2 || echo "yes")
        if [ "$stub" = "yes" ] || [ -z "$stub" ]; then
            log_warn "DNSStubListener=yes — port 53 conflict likely"
            return 1
        else
            log_ok "DNSStubListener=$stub — no conflict"
            return 0
        fi
    else
        log_ok "systemd-resolved is not running"
        return 0
    fi
}

do_check() {
    echo "=== Checking DNS port 53 status ==="
    check_port_53
    local port_ok=$?
    check_systemd_resolved
    local resolved_ok=$?
    if [ $port_ok -eq 0 ] && [ $resolved_ok -eq 0 ]; then
        log_ok "All clear — AdGuard Home can bind to port 53"
    else
        echo ""
        log_warn "Run: sudo $0 --apply  to fix the conflict"
    fi
}

do_apply() {
    echo "=== Applying fix for systemd-resolved port 53 conflict ==="
    if [ "$(id -u)" -ne 0 ]; then
        log_err "This action requires root. Run: sudo $0 --apply"
        exit 1
    fi

    if ! systemctl is-active systemd-resolved &>/dev/null; then
        log_ok "systemd-resolved is not running — nothing to fix"
        exit 0
    fi

    cp "$RESOLVED_CONF" "$BACKUP"
    log_ok "Backed up $RESOLVED_CONF to $BACKUP"

    if grep -q '^DNSStubListener=' "$RESOLVED_CONF"; then
        sed -i 's/^DNSStubListener=.*/DNSStubListener=no/' "$RESOLVED_CONF"
    else
        echo "DNSStubListener=no" >> "$RESOLVED_CONF"
    fi
    log_ok "Set DNSStubListener=no in $RESOLVED_CONF"

    systemctl restart systemd-resolved
    log_ok "Restarted systemd-resolved"

    mkdir -p /etc/systemd/resolved.conf.d 2>/dev/null || true
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf 2>/dev/null || true
    log_ok "Updated /etc/resolv.conf symlink"

    sleep 2
    check_port_53
    if [ $? -eq 0 ]; then
        log_ok "Port 53 is now free — AdGuard Home can start"
    else
        log_err "Port 53 is still occupied — check: ss -ulnp 'sport = :53'"
    fi
}

do_restore() {
    echo "=== Restoring systemd-resolved original config ==="
    if [ "$(id -u)" -ne 0 ]; then
        log_err "This action requires root. Run: sudo $0 --restore"
        exit 1
    fi

    if [ -f "$BACKUP" ]; then
        cp "$BACKUP" "$RESOLVED_CONF"
        log_ok "Restored $RESOLVED_CONF from backup"
    else
        log_warn "No backup found at $BACKUP — manually set DNSStubListener=yes"
        if grep -q '^DNSStubListener=' "$RESOLVED_CONF"; then
            sed -i 's/^DNSStubListener=.*/DNSStubListener=yes/' "$RESOLVED_CONF"
        else
            echo "DNSStubListener=yes" >> "$RESOLVED_CONF"
        fi
    fi

    systemctl restart systemd-resolved
    log_ok "Restarted systemd-resolved with stub listener enabled"

    rm -f /etc/systemd/resolved.conf.d/no-stub.conf 2>/dev/null || true
    log_ok "Restored default DNS resolution"
}

case "${1:-}" in
    --check)  do_check  ;;
    --apply)  do_apply  ;;
    --restore) do_restore ;;
    *)
        echo "Usage: $0 {--check|--apply|--restore}"
        echo ""
        echo "  --check   Check if port 53 is occupied by systemd-resolved"
        echo "  --apply   Disable systemd-resolved stub listener (free port 53)"
        echo "  --restore Re-enable systemd-resolved stub listener"
        exit 1
        ;;
esac
