#!/usr/bin/env bash
# =============================================================================
# CN Mirror Configuration Script
# =============================================================================
# Automatically configures Docker registry mirrors for Chinese network environment
# Supports multiple mirror sources with automatic speed testing and failover
#
# Usage:
#   ./setup-cn-mirrors.sh              # Interactive setup
#   ./setup-cn-mirrors.sh --auto       # Automatic configuration
#   ./setup-cn-mirrors.sh --test       # Test mirror speeds only
#   ./setup-cn-mirrors.sh --restore    # Restore original configuration
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Configuration
DAEMON_JSON="/etc/docker/daemon.json"
DAEMON_JSON_BACKUP="/etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)"
MIRROR_CACHE_DIR="/var/cache/docker-mirrors"
MIRROR_CACHE_FILE="$MIRROR_CACHE_DIR/mirror-speeds.json"

# Mirror sources (ordered by reliability)
# These are public mirrors available in China
DOCKER_MIRRORS=(
  "https://docker.m.daocloud.io"
  "https://dockerhub.timeweb.cloud"
  "https://dockerhub.azk8s.cn"
  "https://registry.docker-cn.com"
  "https://docker.mirrors.ustc.edu.cn"
  "https://hub-mirror.c.163.com"
)

# Alternative registry mirrors
REGISTRY_MIRRORS=(
  "gcr.m.daocloud.io"
  "ghcr.m.daocloud.io"
  "k8s-gcr.m.daocloud.io"
  "k8s.m.daocloud.io"
  "quay.m.daocloud.io"
)

# =============================================================================
# Help
# =============================================================================
show_help() {
    cat << EOF
CN Mirror Configuration Script

Automatically configures Docker registry mirrors for Chinese network environment.

Usage:
  $0 [OPTIONS]

Options:
  --auto       Automatic configuration without prompts
  --test       Test mirror speeds and exit
  --restore    Restore original Docker configuration
  --status     Show current mirror configuration
  -h, --help   Show this help message

Features:
  - Automatic mirror speed testing
  - Multi-mirror fallback configuration
  - Registry mirror support (gcr.io, ghcr.io, etc.)
  - Configuration backup and restore
  - Network environment detection

Examples:
  # Interactive setup
  $0

  # Automatic configuration
  $0 --auto

  # Test mirror speeds
  $0 --test

  # Restore backup
  $0 --restore

EOF
}

# =============================================================================
# Utility Functions
# =============================================================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

detect_cn_network() {
    # Try multiple methods to detect if we're in China
    local cn_detected=false
    
    # Method 1: Check timezone
    if timedatectl show 2>/dev/null | grep -q "Timezone=Asia/Shanghai"; then
        cn_detected=true
    fi
    
    # Method 2: Check language/locale
    if echo "$LANG" | grep -qi "zh_CN\|zh_TW"; then
        cn_detected=true
    fi
    
    # Method 3: Check connectivity to CN mirrors vs international
    local cn_latency intl_latency
    cn_latency=$(curl -o /dev/null -s -w '%{time_total}' \
        --connect-timeout 3 --max-time 5 "https://docker.m.daocloud.io" 2>/dev/null || echo "999")
    intl_latency=$(curl -o /dev/null -s -w '%{time_total}' \
        --connect-timeout 3 --max-time 5 "https://registry-1.docker.io" 2>/dev/null || echo "999")
    
    if (( $(echo "$cn_latency < $intl_latency" | bc -l) )); then
        cn_detected=true
    fi
    
    echo "$cn_detected"
}

test_mirror_speed() {
    local mirror="$1"
    local start_time end_time latency
    
    start_time=$(date +%s%3N)
    
    if curl -f -s --connect-timeout 3 --max-time 10 "$mirror/v2/" > /dev/null 2>&1; then
        end_time=$(date +%s%3N)
        latency=$(( (end_time - start_time) / 1000 ))
        echo "$latency"
    else
        echo "999999"  # Failed
    fi
}

# =============================================================================
# Mirror Testing
# =============================================================================
test_all_mirrors() {
    log_info "Testing mirror speeds..."
    echo ""
    
    declare -A mirror_speeds
    
    for mirror in "${DOCKER_MIRRORS[@]}"; do
        printf "%-50s" "Testing $mirror..."
        speed=$(test_mirror_speed "$mirror")
        
        if [[ "$speed" == "999999" ]]; then
            echo -e "${RED}FAILED${NC}"
            mirror_speeds["$mirror"]="999999"
        else
            if (( speed < 200 )); then
                echo -e "${GREEN}${speed}ms${NC}"
            elif (( speed < 500 )); then
                echo -e "${YELLOW}${speed}ms${NC}"
            else
                echo -e "${RED}${speed}ms${NC}"
            fi
            mirror_speeds["$mirror"]="$speed"
        fi
    done
    
    # Sort and display fastest mirrors
    echo ""
    log_info "Fastest mirrors:"
    for mirror in "${!mirror_speeds[@]}"; do
        echo "${mirror_speeds[$mirror]}:$mirror"
    done | sort -n | head -5 | while read -r line; do
        speed=$(echo "$line" | cut -d: -f1)
        mirror=$(echo "$line" | cut -d: -f2-)
        if [[ "$speed" != "999999" ]]; then
            echo "  - $mirror (${speed}ms)"
        fi
    done
    
    # Save results to cache
    mkdir -p "$MIRROR_CACHE_DIR"
    echo "{" > "$MIRROR_CACHE_FILE"
    first=true
    for mirror in "${!mirror_speeds[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$MIRROR_CACHE_FILE"
        fi
        echo "  \"$mirror\": ${mirror_speeds[$mirror]}" >> "$MIRROR_CACHE_FILE"
    done
    echo "" >> "$MIRROR_CACHE_FILE"
    echo "}" >> "$MIRROR_CACHE_FILE"
    
    log_info "Mirror speeds cached to $MIRROR_CACHE_FILE"
}

# =============================================================================
# Configuration Functions
# =============================================================================
backup_config() {
    if [[ -f "$DAEMON_JSON" ]]; then
        cp "$DAEMON_JSON" "$DAEMON_JSON_BACKUP"
        log_info "Backed up $DAEMON_JSON to $DAEMON_JSON_BACKUP"
    fi
}

restore_config() {
    local latest_backup
    latest_backup=$(ls -t /etc/docker/daemon.json.backup.* 2>/dev/null | head -1)
    
    if [[ -n "$latest_backup" ]]; then
        cp "$latest_backup" "$DAEMON_JSON"
        log_info "Restored configuration from $latest_backup"
        systemctl restart docker
        log_info "Docker restarted"
    else
        log_error "No backup found"
        exit 1
    fi
}

get_fastest_mirrors() {
    local count="${1:-3}"
    local fastest=()
    
    # Load from cache if available
    if [[ -f "$MIRROR_CACHE_FILE" ]]; then
        while read -r line; do
            mirror=$(echo "$line" | cut -d: -f2-)
            fastest+=("$mirror")
        done < <(jq -r 'to_entries | sort_by(.value) | .[] | "\(.value):\(.key)"' "$MIRROR_CACHE_FILE" | head -n "$count")
    else
        # Use default mirrors if no cache
        fastest=("${DOCKER_MIRRORS[@]:0:$count}")
    fi
    
    echo "${fastest[@]}"
}

configure_mirrors() {
    local auto="${1:-false}"
    
    check_root
    
    # Detect network environment
    local is_cn
    is_cn=$(detect_cn_network)
    
    if [[ "$is_cn" == "false" && "$auto" == "false" ]]; then
        log_warn "Non-Chinese network environment detected"
        read -r -p "Continue with CN mirror configuration? (y/N): " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    # Test mirrors if cache is old or missing
    if [[ ! -f "$MIRROR_CACHE_FILE" ]] || \
       [[ $(find "$MIRROR_CACHE_FILE" -mtime +1 2>/dev/null) ]]; then
        test_all_mirrors
    fi
    
    # Get fastest mirrors
    local mirrors
    mirrors=$(get_fastest_mirrors 3)
    
    # Backup existing configuration
    backup_config
    
    # Build new configuration
    local new_config
    if [[ -f "$DAEMON_JSON" ]]; then
        # Merge with existing configuration
        new_config=$(jq --argjson mirrors "$(printf '%s\n' "${mirrors[@]}" | jq -R . | jq -s .)" \
            '. + {"registry-mirrors": $mirrors}' "$DAEMON_JSON")
    else
        # Create new configuration
        new_config=$(cat <<EOF
{
  "registry-mirrors": [
$(printf '%s\n' "${mirrors[@]}" | jq -R . | paste -sd ',' -)
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  }
}
EOF
)
    fi
    
    # Write configuration
    echo "$new_config" | jq '.' > "$DAEMON_JSON"
    log_info "Updated $DAEMON_JSON"
    
    # Restart Docker
    log_info "Restarting Docker..."
    systemctl restart docker
    
    # Verify
    sleep 3
    if systemctl is-active --quiet docker; then
        log_info "✓ Docker restarted successfully"
        log_info "Configured mirrors:"
        jq -r '.["registry-mirrors"][]' "$DAEMON_JSON" | while read -r mirror; do
            echo "  - $mirror"
        done
    else
        log_error "✗ Docker failed to restart"
        log_error "Restoring backup..."
        restore_config
        exit 1
    fi
}

show_status() {
    log_info "Current Docker mirror configuration:"
    echo ""
    
    if [[ -f "$DAEMON_JSON" ]]; then
        echo "Configuration file: $DAEMON_JSON"
        jq '.' "$DAEMON_JSON"
        echo ""
        
        if jq -e '.["registry-mirrors"]' "$DAEMON_JSON" > /dev/null 2>&1; then
            log_info "Configured mirrors:"
            jq -r '.["registry-mirrors"][]' "$DAEMON_JSON" | while read -r mirror; do
                echo "  - $mirror"
            done
        else
            log_warn "No mirrors configured"
        fi
    else
        log_warn "No Docker configuration file found"
    fi
    
    # Show available backups
    echo ""
    if ls /etc/docker/daemon.json.backup.* 1> /dev/null 2>&1; then
        log_info "Available backups:"
        ls -lht /etc/docker/daemon.json.backup.* | head -5
    fi
}

# =============================================================================
# Main
# =============================================================================
main() {
    local mode="interactive"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                mode="auto"
                shift
                ;;
            --test)
                test_all_mirrors
                exit 0
                ;;
            --restore)
                restore_config
                exit 0
                ;;
            --status)
                show_status
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    case "$mode" in
        auto)
            configure_mirrors true
            ;;
        interactive)
            configure_mirrors false
            ;;
    esac
}

main "$@"
