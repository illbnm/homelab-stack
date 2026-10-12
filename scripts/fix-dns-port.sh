#!/bin/bash

# scripts/fix-dns-port.sh
# Detects and disables systemd-resolved's 53 port listener.
# Supports --check, --apply, --restore.

RESOLVED_CONF="/etc/systemd/resolved.conf"
RESOLVED_CONF_BACKUP="/etc/systemd/resolved.conf.bak"
RESOLVED_SERVICE="systemd-resolved.service"

# Function to check if systemd-resolved is listening on port 53
check_port_53() {
    echo "Checking if systemd-resolved is listening on port 53..."
    if ss -ltu sport = 53 | grep -q "systemd-resolve"; then
        echo "  systemd-resolved is currently listening on port 53."
        return 0
    else
        echo "  systemd-resolved is NOT listening on port 53."
        return 1
    fi
}

# Function to apply the fix
apply_fix() {
    echo "Applying fix to disable systemd-resolved's port 53 listener..."

    if [ ! -f "$RESOLVED_CONF" ]; then
        echo "Error: $RESOLVED_CONF not found. Cannot apply fix."
        exit 1
    fi

    # Create a backup if it doesn't exist
    if [ ! -f "$RESOLVED_CONF_BACKUP" ]; then
        echo "  Creating backup of $RESOLVED_CONF to $RESOLVED_CONF_BACKUP"
        sudo cp "$RESOLVED_CONF" "$RESOLVED_CONF_BACKUP"
    else
        echo "  Backup $RESOLVED_CONF_BACKUP already exists."
    fi

    # Modify resolved.conf
    if grep -q "^#*DNSStubListener=" "$RESOLVED_CONF"; then
        if grep -q "^DNSStubListener=no" "$RESOLVED_CONF"; then
            echo "  DNSStubListener is already set to 'no' in $RESOLVED_CONF."
        else
            echo "  Setting DNSStubListener=no in $RESOLVED_CONF..."
            sudo sed -i 's/^#*DNSStubListener=.*/DNSStubListener=no/' "$RESOLVED_CONF"
        fi
    else
        echo "  Adding DNSStubListener=no to $RESOLVED_CONF..."
        echo "DNSStubListener=no" | sudo tee -a "$RESOLVED_CONF" > /dev/null
    fi

    # Restart systemd-resolved
    echo "  Restarting $RESOLVED_SERVICE..."
    sudo systemctl restart "$RESOLVED_SERVICE"

    # Verify the change
    if check_port_53; then
        echo "  Fix applied, but systemd-resolved is still listening on port 53. Please check logs."
        exit 1
    else
        echo "  Fix applied successfully. systemd-resolved is no longer listening on port 53."
    fi

    # Update /etc/resolv.conf to point to localhost (AdGuard Home)
    echo "  Updating /etc/resolv.conf to point to 127.0.0.1..."
    echo -e "nameserver 127.0.0.1\noptions edns0 trust-ad\nsearch ." | sudo tee /etc/resolv.conf > /dev/null
    echo "  /etc/resolv.conf updated. You might need to restart network services or reboot for full effect."
}

# Function to restore the original configuration
restore_fix() {
    echo "Restoring original systemd-resolved configuration..."

    if [ -f "$RESOLVED_CONF_BACKUP" ]; then
        echo "  Restoring $RESOLVED_CONF from $RESOLVED_CONF_BACKUP..."
        sudo cp "$RESOLVED_CONF_BACKUP" "$RESOLVED_CONF"
        echo "  Restarting $RESOLVED_SERVICE..."
        sudo systemctl restart "$RESOLVED_SERVICE"
        echo "  Original configuration restored. systemd-resolved should now listen on port 53 again."
        # Restore /etc/resolv.conf to its default symlink
        echo "  Restoring /etc/resolv.conf symlink..."
        sudo rm /etc/resolv.conf
        sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        echo "  /etc/resolv.conf symlink restored."
    else
        echo "  No backup found at $RESOLVED_CONF_BACKUP. Cannot restore."
        exit 1
    fi
}

# Main script logic
case "$1" in
    --check)
        check_port_53
        ;;
    --apply)
        apply_fix
        ;;
    --restore)
        restore_fix
        ;;
    *)
        echo "Usage: $0 [--check | --apply | --restore]"
        echo "  --check   : Check if systemd-resolved is listening on port 53."
        echo "  --apply   : Disable systemd-resolved's port 53 listener and update resolv.conf."
        echo "  --restore : Restore original systemd-resolved configuration and resolv.conf."
        exit 1
        ;;
esac

exit 0
