#!/bin/bash
# Script to configure Docker daemon with CN mirrors.

# Source common utilities
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"

# Exit on error
set -e

check_root

DOCKER_DAEMON_FILE="/etc/docker/daemon.json"
DOCKER_CONFIG_DIR="/etc/docker"

# Supported mirror sources
declare -A MIRROR_SOURCES
MIRROR_SOURCES["DaoCloud"]="https://docker.m.daocloud.io"
MIRROR_SOURCES["163"]="https://hub-mirror.c.163.com"
MIRROR_SOURCES["Baidu"]="https://mirror.baidubce.com"
MIRROR_SOURCES["Tsinghua"]="https://mirror.tuna.tsinghua.edu.cn" # Often used for apt, but some provide docker mirrors

# Function to configure Docker daemon
configure_docker_daemon() {
    local selected_mirror="$1"
    local mirrors_array=()

    # Always include the selected mirror first
    mirrors_array+=("\"${selected_mirror}\"")

    # Add other mirrors as fallbacks, excluding the selected one
    for name in "${!MIRROR_SOURCES[@]}"; do
        local url="${MIRROR_SOURCES[$name]}"
        if [[ "$url" != "$selected_mirror" ]]; then
            mirrors_array+=("\"${url}\"")
        fi
    done

    local mirrors_json=$(IFS=,; echo "${mirrors_array[*]}")

    ensure_dir "$DOCKER_CONFIG_DIR"

    # Read existing daemon.json if it exists
    local existing_config="{}"
    if [ -f "$DOCKER_DAEMON_FILE" ]; then
        existing_config=$(cat "$DOCKER_DAEMON_FILE")
    fi

    # Use jq to merge or create the config
    if ! command_exists jq; then
        log_warn "jq not found. Attempting to install jq for robust JSON manipulation."
        install_jq
        if ! command_exists jq; then
            log_error "jq installation failed. Cannot robustly update daemon.json. Please install jq manually or proceed with caution."
            log_error "Manual update: Add \"registry-mirrors\": [${mirrors_json}] to $DOCKER_DAEMON_FILE"
            return 1
        fi
    fi

    local new_config=$(echo "$existing_config" | jq --argjson mirrors "[${mirrors_json}]" '. + {"registry-mirrors": $mirrors}')

    log_info "Writing Docker daemon configuration to $DOCKER_DAEMON_FILE..."
    echo "$new_config" > "$DOCKER_DAEMON_FILE"

    log_info "Reloading Docker daemon..."
    systemctl daemon-reload
    systemctl restart docker

    log_success "Docker daemon configured with mirrors. Verifying..."

    # Verify configuration
    if docker info | grep -q "Registry Mirrors:.*${selected_mirror}"; then
        log_success "Docker daemon successfully configured with mirror: ${selected_mirror}"
        return 0
    else
        log_error "Failed to verify Docker daemon mirror configuration."
        return 1
    fi
}

# Function to install jq
install_jq() {
    local os_type=$(get_os_type)
    case "$os_type" in
        ubuntu|debian)
            apt update && apt install -y jq
            ;;
        centos|rhel|fedora)
            yum install -y jq || dnf install -y jq
            ;;
        arch)
            pacman -Sy --noconfirm jq
            ;;
        alpine)
            apk add jq
            ;;
        *)
            log_error "Unsupported OS for automatic jq installation: $os_type. Please install jq manually."
            return 1
            ;;
    esac
    return $?
}

# Main execution
log_info "Starting Docker mirror configuration script."

if ! command_exists docker; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! systemctl is-active --quiet docker; then
    log_warn "Docker daemon is not running. Attempting to start it."
    systemctl start docker || log_error "Failed to start Docker daemon. Please check Docker installation."
    sleep 5 # Give Docker some time to start
    if ! systemctl is-active --quiet docker; then
        log_error "Docker daemon failed to start. Exiting."
        exit 1
    fi
fi

# Ask if user is in mainland China
if prompt_yes_no "Are you in mainland China or experiencing slow Docker pulls?"; then
    log_info "Please select a primary Docker mirror source:"
    select_options=()
    for name in "${!MIRROR_SOURCES[@]}"; do
        select_options+=("$name (${MIRROR_SOURCES[$name]})")
    done

    PS3="Enter the number of your preferred mirror: "
    select selected_option in "${select_options[@]}"; do
        if [[ -n "$selected_option" ]]; then
            # Extract URL from the selected option string
            selected_mirror_url=$(echo "$selected_option" | sed -E 's/.*\(https?:\/\/[^)]+\)/\1/')
            log_info "You selected: $selected_option"
            break
        else
            log_error "Invalid selection. Please try again."
        fi
    done

    if configure_docker_daemon "$selected_mirror_url"; then
        log_info "Attempting to pull 'hello-world' to verify mirror functionality..."
        if docker pull hello-world; then
            log_success "Successfully pulled 'hello-world' using the configured mirrors. Docker mirror setup complete!"
        else
            log_error "Failed to pull 'hello-world' after configuring mirrors. Please check your network or mirror configuration."
            exit 1
        fi
    else
        log_error "Docker mirror configuration failed."
        exit 1
    fi
else
    log_info "Skipping Docker mirror configuration as requested."
fi

log_success "Script finished."
