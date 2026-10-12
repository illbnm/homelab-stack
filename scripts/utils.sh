#!/bin/bash
# Common utility functions for homelab-stack scripts

# Exit immediately if a command exits with a non-zero status.
set -e

# Function to print messages with different colors
COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'

log_info() {
    echo -e "${COLOR_CYAN}[INFO]${COLOR_RESET} $1"
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $1"
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $1"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1" >&2
}

log_debug() {
    if [[ "${DEBUG}" == "true" ]]; then
        echo -e "${COLOR_BLUE}[DEBUG]${COLOR_RESET} $1"
    fi
}

# Function to perform curl with retries and exponential backoff
curl_retry() {
    local max_attempts=3
    local delay=5
    local url="$1"
    shift # Remove the URL from arguments, rest are curl options
    local curl_opts=("$@")

    log_debug "Attempting to curl: ${url} with options: ${curl_opts[*]}"

    for i in $(seq 1 $max_attempts); do
        if curl --connect-timeout 10 --max-time 60 "${curl_opts[@]}" "${url}"; then
            log_debug "Curl attempt $i successful."
            return 0
        else
            log_warn "Curl attempt $i failed for ${url}. Retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))
        fi
    done
    log_error "Failed to curl ${url} after $max_attempts attempts."
    return 1
}

# Function to check if the current network is likely in mainland China
# This is a heuristic based on common services' reachability.
is_cn_network() {
    log_info "Detecting network environment..."
    local cn_score=0
    local total_checks=0

    # Check common services that are often blocked or slow in CN
    # Google (gcr.io, google.com)
    total_checks=$((total_checks + 1))
    if curl_retry https://gcr.io/v2/ --silent --output /dev/null; then
        log_debug "gcr.io is reachable."
    else
        log_debug "gcr.io is unreachable."
        cn_score=$((cn_score + 1))
    fi

    # GitHub (github.com) - often slow
    total_checks=$((total_checks + 1))
    if curl_retry https://github.com --silent --output /dev/null; then
        log_debug "github.com is reachable."
    else
        log_debug "github.com is unreachable."
        cn_score=$((cn_score + 1))
    fi

    # Docker Hub (hub.docker.com) - generally reachable but sometimes slow
    total_checks=$((total_checks + 1))
    if curl_retry https://hub.docker.com --silent --output /dev/null; then
        log_debug "hub.docker.com is reachable."
    else
        log_debug "hub.docker.com is unreachable."
        cn_score=$((cn_score + 1))
    fi

    # Heuristic: If more than half of the "problematic" services are unreachable, assume CN.
    if (( cn_score * 2 >= total_checks )); then
        log_warn "Network detection suggests you might be in mainland China (score: ${cn_score}/${total_checks})."
        return 0 # True, likely CN
    else
        log_info "Network detection suggests you are NOT in mainland China (score: ${cn_score}/${total_checks})."
        return 1 # False, not likely CN
    fi
}

# Function to get OS type
get_os_type() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif type lsb_release >/dev/null 2>&1; then
        lsb_release -si
    elif [ -f /etc/redhat-release ]; then
        cat /etc/redhat-release | awk '{print tolower($1)}'
    else
        echo "unknown"
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to prompt for yes/no
prompt_yes_no() {
    local prompt_message="$1"
    while true; do
        read -rp "${prompt_message} (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Function to check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root. Please use 'sudo $0' or switch to root."
        exit 1
    fi
}

# Function to ensure a directory exists
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        log_info "Creating directory: $dir"
        mkdir -p "$dir"
    fi
}

# Function to get the absolute path of the script's directory
get_script_dir() {
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    echo "$DIR"
}

# Function to check if a port is in use
is_port_in_use() {
    local port="$1"
    if command_exists ss; then
        ss -tuln | grep -q ":$port\b"
    elif command_exists netstat; then
        netstat -tuln | grep -q ":$port\b"
    else
        log_warn "Neither 'ss' nor 'netstat' found. Cannot check port $port usage."
        return 1 # Assume not in use if we can't check
    fi
}
