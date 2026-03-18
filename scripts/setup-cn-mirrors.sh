#!/bin/bash

# Script to configure Docker registry mirrors for China networks
# Provides multiple fallback sources and interactive configuration

set -e

SCRIPT_NAME="Docker CN Mirrors Setup"
DOCKER_DAEMON_CONFIG="/etc/docker/daemon.json"
BACKUP_DIR="/etc/docker/backups"
LOG_FILE="/tmp/docker-mirrors-setup.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Print colored output
print_color() {
    echo -e "${2}${1}${NC}"
}

print_header() {
    echo
    print_color "========================================" "$BLUE"
    print_color "$SCRIPT_NAME" "$BLUE"
    print_color "========================================" "$BLUE"
    echo
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_color "This script must be run as root (use sudo)" "$RED"
        exit 1
    fi
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_color "Docker is not installed. Please install Docker first." "$RED"
        exit 1
    fi
}

# Available mirror sources
declare -A MIRROR_SOURCES=(
    ["aliyun"]="https://registry.cn-hangzhou.aliyuncs.com"
    ["tencent"]="https://mirror.ccs.tencentyun.com"
    ["163"]="https://hub-mirror.c.163.com"
    ["ustc"]="https://docker.mirrors.ustc.edu.cn"
    ["daocloud"]="https://f1361db2.m.daocloud.io"
    ["azure"]="https://dockerhub.azk8s.cn"
    ["seven_cow"]="https://reg-mirror.qiniu.com"
)

# Test mirror connectivity
test_mirror() {
    local mirror_url="$1"
    local timeout=10
    
    print_color "Testing mirror: $mirror_url" "$YELLOW"
    
    if curl -s --connect-timeout $timeout --max-time $timeout "$mirror_url/v2/" > /dev/null 2>&1; then
        print_color "✓ Mirror is accessible" "$GREEN"
        return 0
    else
        print_color "✗ Mirror is not accessible" "$RED"
        return 1
    fi
}

# Get available mirrors
get_working_mirrors() {
    local working_mirrors=()
    
    print_color "Testing mirror connectivity..." "$BLUE"
    echo
    
    for name in "${!MIRROR_SOURCES[@]}"; do
        if test_mirror "${MIRROR_SOURCES[$name]}"; then
            working_mirrors+=("${MIRROR_SOURCES[$name]}")
        fi
        echo
    done
    
    printf '%s\n' "${working_mirrors[@]}"
}

# Backup existing configuration
backup_config() {
    if [[ -f "$DOCKER_DAEMON_CONFIG" ]]; then
        mkdir -p "$BACKUP_DIR"
        local backup_file="$BACKUP_DIR/daemon.json.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$DOCKER_DAEMON_CONFIG" "$backup_file"
        log "Backed up existing configuration to $backup_file"
        print_color "✓ Existing configuration backed up" "$GREEN"
    fi
}

# Create or update Docker daemon configuration
update_docker_config() {
    local mirrors=("$@")
    local config_json
    
    if [[ -f "$DOCKER_DAEMON_CONFIG" ]]; then
        config_json=$(cat "$DOCKER_DAEMON_CONFIG")
    else
        config_json='{}'
        mkdir -p "$(dirname "$DOCKER_DAEMON_CONFIG")"
    fi
    
    # Create mirrors array in JSON format
    local mirrors_json="["
    for i in "${!mirrors[@]}"; do
        mirrors_json+="\"${mirrors[$i]}\""
        if [[ $i -lt $((${#mirrors[@]} - 1)) ]]; then
            mirrors_json+=","
        fi
    done
    mirrors_json+="]"
    
    # Update configuration using jq or manual JSON manipulation
    if command -v jq &> /dev/null; then
        echo "$config_json" | jq --argjson mirrors "$mirrors_json" '.["registry-mirrors"] = $mirrors' > "$DOCKER_DAEMON_CONFIG"
    else
        # Fallback: manual JSON creation
        cat > "$DOCKER_DAEMON_CONFIG" << EOF
{
  "registry-mirrors": $mirrors_json
}
EOF
    fi
    
    log "Updated Docker daemon configuration with $(${#mirrors[@]}) mirrors"
}

# Restart Docker daemon
restart_docker() {
    print_color "Restarting Docker daemon..." "$YELLOW"
    
    if systemctl is-active --quiet docker; then
        if systemctl restart docker; then
            sleep 5  # Wait for Docker to fully restart
            if systemctl is-active --quiet docker; then
                print_color "✓ Docker daemon restarted successfully" "$GREEN"
                return 0
            fi
        fi
    fi
    
    print_color "✗ Failed to restart Docker daemon" "$RED"
    return 1
}

# Verify configuration
verify_config() {
    print_color "Verifying Docker configuration..." "$YELLOW"
    
    if docker info 2>/dev/null | grep -q "Registry Mirrors:"; then
        echo
        print_color "Current registry mirrors:" "$BLUE"
        docker info 2>/dev/null | grep -A 10 "Registry Mirrors:" | head -20
        print_color "✓ Registry mirrors configured successfully" "$GREEN"
        return 0
    else
        print_color "✗ Registry mirrors not found in Docker info" "$RED"
        return 1
    fi
}

# Interactive mirror selection
interactive_selection() {
    local working_mirrors=()
    readarray -t working_mirrors < <(get_working_mirrors)
    
    if [[ ${#working_mirrors[@]} -eq 0 ]]; then
        print_color "No accessible mirrors found. Check your internet connection." "$RED"
        exit 1
    fi
    
    echo
    print_color "Found ${#working_mirrors[@]} working mirrors" "$GREEN"
    echo
    
    while true; do
        print_color "Select configuration option:" "$BLUE"
        echo "1) Use all working mirrors (recommended)"
        echo "2) Select specific mirrors"
        echo "3) Use top 3 fastest mirrors"
        echo "4) Exit without changes"
        echo
        read -p "Enter your choice (1-4): " choice
        
        case $choice in
            1)
                selected_mirrors=("${working_mirrors[@]}")
                break
                ;;
            2)
                select_specific_mirrors working_mirrors
                break
                ;;
            3)
                selected_mirrors=("${working_mirrors[@]:0:3}")
                break
                ;;
            4)
                print_color "Exiting without changes" "$YELLOW"
                exit 0
                ;;
            *)
                print_color "Invalid choice. Please enter 1-4." "$RED"
                ;;
        esac
    done
    
    if [[ ${#selected_mirrors[@]} -eq 0 ]]; then
        print_color "No mirrors selected. Exiting." "$YELLOW"
        exit 0
    fi
    
    echo
    print_color "Selected mirrors:" "$BLUE"
    printf '  %s\n' "${selected_mirrors[@]}"
    echo
    
    read -p "Proceed with configuration? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_color "Configuration cancelled" "$YELLOW"
        exit 0
    fi
}

# Select specific mirrors
select_specific_mirrors() {
    local -n mirrors_ref=$1
    selected_mirrors=()
    
    echo
    print_color "Available mirrors:" "$BLUE"
    for i in "${!mirrors_ref[@]}"; do
        echo "  $((i+1))) ${mirrors_ref[$i]}"
    done
    echo
    
    while true; do
        read -p "Enter mirror numbers (space-separated, e.g., 1 3 5): " numbers
        
        if [[ -z "$numbers" ]]; then
            break
        fi
        
        local valid=true
        for num in $numbers; do
            if ! [[ "$num" =~ ^[0-9]+$ ]] || [[ $num -lt 1 ]] || [[ $num -gt ${#mirrors_ref[@]} ]]; then
                print_color "Invalid number: $num" "$RED"
                valid=false
                break
            fi
        done
        
        if [[ "$valid" == true ]]; then
            for num in $numbers; do
                selected_mirrors+=("${mirrors_ref[$((num-1))]}")
            done
            break
        fi
    done
}

# Main function
main() {
    print_header
    
    check_root
    check_docker
    
    print_color "Starting Docker registry mirrors configuration for China networks" "$BLUE"
    echo
    
    # Initialize log file
    echo "=== Docker CN Mirrors Setup Log ===" > "$LOG_FILE"
    log "Setup started"
    
    # Interactive selection
    interactive_selection
    
    # Backup existing configuration
    backup_config
    
    # Update configuration
    print_color "Updating Docker daemon configuration..." "$YELLOW"
    update_docker_config "${selected_mirrors[@]}"
    
    # Restart Docker
    if ! restart_docker; then
        print_color "Failed to restart Docker. Please check the configuration manually." "$RED"
        log "Docker restart failed"
        exit 1
    fi
    
    # Verify configuration
    if verify_config; then
        echo
        print_color "✓ Docker registry mirrors configured successfully!" "$GREEN"
        print_color "Configuration saved to: $DOCKER_DAEMON_CONFIG" "$BLUE"
        print_color "Backup saved to: $BACKUP_DIR" "$BLUE"
        print_color "Log file: $LOG_FILE" "$BLUE"
        log "Setup completed successfully"
    else
        print_color "Configuration verification failed" "$RED"
        log "Setup verification failed"
        exit 1
    fi
    
    echo
    print_color "You can now use Docker with improved connectivity in China!" "$GREEN"
    print_color "Test with: docker pull hello-world" "$BLUE"
}

# Handle script interruption
trap 'print_color "\nScript interrupted. Docker configuration may be incomplete." "$YELLOW"; exit 1' INT TERM

# Run main function
main "$@"