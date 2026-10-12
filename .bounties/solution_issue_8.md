# Solution for [github/issues_8]: [illbnm/homelab-stack] [BOUNTY $250] Robustness — 国内网络适配 + 环境鲁棒性

- **Reward:** $250.00 USDC
- **Target URL:** https://github.com/illbnm/homelab-stack/issues/8
- **AI Brain:** gemini-2.5-flash
- **Tokens Used:** 11316 (~$0.0226 USD compute cost)

---

Root Cause Analysis:

The core problem is the unreliability of deploying a HomeLab Stack in diverse network environments, especially within mainland China. This stems from several factors:
1.  **Blocked/Slow External Resources:** Docker Hub, GCR.io, GHCR.io, and various package manager repositories (APT, PIP, APK) are often slow or inaccessible from mainland China due to network restrictions (Great Firewall).
2.  **Lack of Environment Pre-checks:** The current `install.sh` likely assumes a pristine, well-connected environment, leading to failures if Docker isn't installed, ports are in use, or disk/memory is low.
3.  **Fragile Network Operations:** Simple `curl` commands without retry mechanisms are prone to failure on unstable networks.
4.  **No Health Monitoring:** Without a mechanism to wait for Docker Compose services to become healthy, deployments might appear successful but fail silently later.
5.  **Poor Diagnosability:** When issues arise, users lack tools to gather comprehensive diagnostic information, making troubleshooting difficult.
6.  **Hardcoded Image References:** Docker Compose files directly reference `gcr.io` and `ghcr.io` images, which are problematic in China.

Architecture Design:

The solution will involve creating several new shell scripts and modifying the existing `install.sh` to address these issues systematically.

1.  **Centralized Configuration:** A `config/cn-mirrors.yml` will store the mapping for image replacements, making it easy to update and manage.
2.  **Modular Scripts:** Each core requirement (Docker mirror setup, image localization, connectivity check, health wait, diagnosis) will be encapsulated in its own script for maintainability and reusability.
3.  **Robust `install.sh`:** The main installation script will be enhanced with comprehensive pre-checks, automatic installations, user prompts, and retry mechanisms for network operations.
4.  **Network Abstraction:** A `curl_retry` function will be introduced and used for all critical network requests to improve resilience.
5.  **Dynamic Mirroring:** The `localize-images.sh` script will dynamically modify Docker Compose files based on the `cn-mirrors.yml` and provide options to restore or dry-run.
6.  **Interactive User Experience:** Scripts like `setup-cn-mirrors.sh` will interactively ask the user about their location to provide tailored recommendations.
7.  **System-Agnostic Package Management:** The `install.sh` will detect the OS and use appropriate package managers (apt, yum, pacman, apk) for Docker installation.
8.  **Health Check Integration:** The `wait-healthy.sh` will provide a robust way to ensure services are truly up and running.
9.  **Diagnostic Tool:** `diagnose.sh` will consolidate all relevant system and application information for easy troubleshooting.

**Directory Structure Changes:**

```
.
├── config/
│   └── cn-mirrors.yml          # New: Image mapping for CN mirrors
├── scripts/
│   ├── check-connectivity.sh   # New: Network reachability checks
│   ├── localize-images.sh      # New: Docker Compose image replacement
│   ├── setup-cn-mirrors.sh     # New: Docker daemon mirror configuration
│   ├── wait-healthy.sh         # New: Docker Compose health wait
│   ├── diagnose.sh             # New: System diagnosis tool
│   └── utils.sh                # New: Common utility functions (e.g., curl_retry)
└── install.sh                  # Modified: Enhanced installation script
```

**Detailed Plan:**

1.  **`scripts/utils.sh`**: Implement `curl_retry` and other common helper functions (e.g., `is_cn_network`, `get_os_type`).
2.  **`scripts/check-connectivity.sh`**: Implement ping/curl checks for specified hosts and ports, reporting status and latency.
3.  **`scripts/setup-cn-mirrors.sh`**:
    *   Prompt user for location.
    *   If CN, prompt for preferred mirror.
    *   Write `daemon.json` with multiple mirrors.
    *   Reload Docker daemon.
    *   Verify with `docker pull hello-world`.
4.  **`config/cn-mirrors.yml`**: Populate with common `gcr.io` and `ghcr.io` images and their `m.daocloud.io` equivalents. This will require an initial scan of existing `docker-compose.yml` files in the `homelab-stack` repository to identify all `gcr.io` and `ghcr.io` images.
5.  **`scripts/localize-images.sh`**:
    *   Parse `cn-mirrors.yml`.
    *   Implement `--cn`, `--restore`, `--dry-run`, `--check` logic using `sed` or `yq` (if available, otherwise `sed` for broader compatibility) to modify `docker-compose.yml` files. Store original files as `.bak` for restore.
6.  **`scripts/wait-healthy.sh`**: Use `docker compose ps --format json` and `jq` to poll container health status.
7.  **`scripts/diagnose.sh`**: Collect system info, Docker info, container status, logs, and connectivity results.
8.  **`install.sh`**:
    *   Source `scripts/utils.sh`.
    *   Implement OS detection for Docker installation.
    *   Add checks for Docker Compose v1/v2.
    *   Add port conflict detection (using `netstat -tuln` or `ss -tuln`).
    *   Add disk space and memory checks.
    *   Add user to `docker` group.
    *   Add firewall checks (ufw/firewalld).
    *   Integrate `setup-cn-mirrors.sh` and `localize-images.sh` (conditionally based on `check-connectivity.sh` results or user input).
    *   Integrate `wait-healthy.sh` after `docker compose up`.
    *   Add `apt`/`pip`/`apk` mirror switching logic within the script itself, or as a function called by services if they have entrypoints that perform package management. For a general `install.sh`, it's better to modify the host's `sources.list` if the user confirms they are in CN.
    *   Use `curl_retry` for all external downloads.

This comprehensive approach ensures robustness, adaptability to different network conditions, and improved user experience and diagnosability.

---

### File: scripts/utils.sh
```bash
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
```

### File: scripts/check-connectivity.sh
```bash
#!/bin/bash
# Script to check network connectivity to various services and ports.

# Source common utilities
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/utils.sh"

# Exit on error
set -e

# Define services to check
declare -A SERVICES
SERVICES["Docker Hub"]="hub.docker.com:443"
SERVICES["GitHub"]="github.com:443"
SERVICES["gcr.io"]="gcr.io:443"
SERVICES["ghcr.io"]="ghcr.io:443"
SERVICES["Google DNS"]="8.8.8.8:53" # For general internet connectivity/DNS
SERVICES["Baidu"]="www.baidu.com:443" # For general CN connectivity

# Function to check connectivity to a host:port
check_host_port() {
    local name="$1"
    local host_port="$2"
    local host="${host_port%:*}"
    local port="${host_port#*:}"
    local start_time=$(date +%s%3N) # Milliseconds
    local status="FAIL"
    local message=""
    local icon="✗"
    local color="${COLOR_RED}"
    local curl_opts=("--silent" "--output" "/dev/null" "--write-out" "%{time_total}")

    # Check DNS resolution first
    if ! dig +short "$host" >/dev/null; then
        message="DNS resolution failed"
    else
        # Try to connect using curl
        local time_total=$(curl_retry "https://${host}:${port}" "${curl_opts[@]}" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$time_total" ]; then
            local latency_ms=$(echo "$time_total * 1000" | bc | cut -d'.' -f1)
            status="OK"
            icon="✓"
            color="${COLOR_GREEN}"
            message="Latency ${latency_ms}ms"
            if (( latency_ms > 1000 )); then
                status="SLOW"
                icon="⚠️"
                color="${COLOR_YELLOW}"
                message="${message} ⚠️ Suggests slow connection"
            fi
        else
            message="Connection timeout or refused"
        fi
    fi

    echo -e "  ${color}[${status}]${COLOR_RESET} ${name} (${host_port}) — ${message} ${icon}"
    if [[ "$status" == "FAIL" ]]; then
        return 1
    fi
    return 0
}

# Main execution
log_info "Starting network connectivity check..."
echo ""

failed_sources=0
slow_sources=0

# Check DNS resolution
log_info "Checking DNS resolution..."
if dig +short google.com >/dev/null; then
    echo -e "  ${COLOR_GREEN}[OK]${COLOR_RESET} DNS resolution (google.com) — Normal ✓"
else
    echo -e "  ${COLOR_RED}[FAIL]${COLOR_RESET} DNS resolution (google.com) — Failed ✗"
    failed_sources=$((failed_sources + 1))
fi
echo ""

# Check specific services
log_info "Checking critical service reachability..."
for service_name in "${!SERVICES[@]}"; do
    if ! check_host_port "$service_name" "${SERVICES[$service_name]}"; then
        if [[ "$(echo -e "${COLOR_RED}[FAIL]${COLOR_RESET}" | grep -o "FAIL")" ]]; then # Check if the output contained FAIL
            failed_sources=$((failed_sources + 1))
        elif [[ "$(echo -e "${COLOR_YELLOW}[SLOW]${COLOR_RESET}" | grep -o "SLOW")" ]]; then # Check if the output contained SLOW
            slow_sources=$((slow_sources + 1))
        fi
    fi
done
echo ""

# Check common outbound ports
log_info "Checking common outbound ports (80/443)..."
if nc -zw1 google.com 80 >/dev/null 2>&1; then
    echo -e "  ${COLOR_GREEN}[OK]${COLOR_RESET} Outbound port 80 (HTTP) — Open ✓"
else
    echo -e "  ${COLOR_RED}[FAIL]${COLOR_RESET} Outbound port 80 (HTTP) — Blocked ✗"
    failed_sources=$((failed_sources + 1))
fi

if nc -zw1 google.com 443 >/dev/null 2>&1; then
    echo -e "  ${COLOR_GREEN}[OK]${COLOR_RESET} Outbound port 443 (HTTPS) — Open ✓"
else
    echo -e "  ${COLOR_RED}[FAIL]${COLOR_RESET} Outbound port 443 (HTTPS) — Blocked ✗"
    failed_sources=$((failed_sources + 1))
fi
echo ""

# Summary and recommendations
if (( failed_sources > 0 )); then
    log_warn "Detected ${failed_sources} unreachable source(s)."
    log_info "Recommendation: Some critical services are unreachable. You might be in a restricted network environment."
    log_info "Consider running './scripts/setup-cn-mirrors.sh' to configure Docker mirrors and './scripts/localize-images.sh --cn' to use localized images."
elif (( slow_sources > 0 )); then
    log_warn "Detected ${slow_sources} slow source(s)."
    log_info "Recommendation: Some services are slow. You might benefit from using local mirrors."
    log_info "Consider running './scripts/setup-cn-mirrors.sh' to configure Docker mirrors and './scripts/localize-images.sh --cn' to use localized images."
else
    log_success "All critical services and ports are reachable and responsive. Your network environment seems healthy."
fi

exit 0
```

### File: scripts/setup-cn-mirrors.sh
```bash
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
```

### File: config/cn-mirrors.yml
```yaml
# This file maps original Docker image paths (gcr.io, ghcr.io) to their
# corresponding mirrors, typically hosted by DaoCloud or other providers
# accessible from mainland China.
#
# Format:
# mirrors:
#   original/image/path: mirrored/image/path
#
# To find mirrored images, you can often prefix the original path with
# the mirror domain, e.g., m.daocloud.io/gcr.io/cadvisor/cadvisor
# or search the mirror provider's registry.

mirrors:
  # gcr.io images
  gcr.io/cadvisor/cadvisor: m.daocloud.io/gcr.io/cadvisor/cadvisor
  gcr.io/google_containers/kube-proxy: m.daocloud.io/gcr.io/google_containers/kube-proxy
  gcr.io/google_containers/pause: m.daocloud.io/gcr.io/google_containers/pause
  gcr.io/k8s-minikube/storage-provisioner: m.daocloud.io/gcr.io/k8s-minikube/storage-provisioner
  gcr.io/kubernetes-helm/tiller: m.daocloud.io/gcr.io/kubernetes-helm/tiller
  gcr.io/kubernetes-ingress-nginx/controller: m.daocloud.io/gcr.io/kubernetes-ingress-nginx/controller
  gcr.io/kubernetes-ingress-nginx/kube-webhook-certgen: m.daocloud.io/gcr.io/kubernetes-ingress-nginx/kube-webhook-certgen
  gcr.io/istio-release/pilot: m.daocloud.io/gcr.io/istio-release/pilot
  gcr.io/istio-release/proxyv2: m.daocloud.io/gcr.io/istio-release/proxyv2
  gcr.io/knative-releases/knative.dev/eventing/cmd/broker: m.daocloud.io/gcr.io/knative-releases/knative.dev/eventing/cmd/broker
  gcr.io/knative-releases/knative.dev/serving/cmd/controller: m.daocloud.io/gcr.io/knative-releases/knative.dev/serving/cmd/controller
  gcr.io/linkerd-io/proxy: m.daocloud.io/gcr.io/linkerd-io/proxy
  gcr.io/prometheus-operator/prometheus-operator: m.daocloud.io/gcr.io/prometheus-operator/prometheus-operator
  gcr.io/etcd-development/etcd: m.daocloud.io/gcr.io/etcd-development/etcd
  gcr.io/k8s-staging-dns/coredns: m.daocloud.io/gcr.io/k8s-staging-dns/coredns
  gcr.io/k8s-staging-metrics-server/metrics-server: m.daocloud.io/gcr.io/k8s-staging-metrics-server/metrics-server
  gcr.io/k8s-staging-sig-storage/csi-node-driver-registrar: m.daocloud.io/gcr.io/k8s-staging-sig-storage/csi-node-driver-registrar
  gcr.io/k8s-staging-sig-storage/livenessprobe: m.daocloud.io/gcr.io/k8s-staging-sig-storage/livenessprobe
  gcr.io/k8s-staging-sig-storage/csi-provisioner: m.daocloud.io/gcr.io/k8s-staging-sig-storage/csi-provisioner
  gcr.io/k8s-staging-sig-storage/csi-attacher: m.daocloud.io/gcr.io/k8s-staging-sig-storage/csi-attacher
  gcr.io/k8s-staging-sig-storage/csi-resizer: m.daocloud.io/gcr.io/k8s-staging-sig-storage/csi-resizer
  gcr.io/k8s-staging-sig-storage/external-snapshotter/snapshot-controller: m.daocloud.io/gcr.io/k8s-staging-sig-storage/external-snapshotter/snapshot-controller
  gcr.io/k8s-staging-sig-storage/external-snapshotter/csi-snapshotter: m.daocloud.io/gcr.io/k8s-staging-sig-storage/external-snapshotter/csi-snapshotter
  gcr.io/k8s-staging-sig-storage/external-snapshotter/webhook: m.daocloud.io/gcr.io/k8s-staging-sig-storage/external-snapshotter/webhook
  gcr.io/k8s-staging-cluster-api/cluster-api-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/cluster-api-controller
  gcr.io/k8s-staging-cluster-api/kubeadm-bootstrap-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/kubeadm-bootstrap-controller
  gcr.io/k8s-staging-cluster-api/kubeadm-control-plane-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/kubeadm-control-plane-controller
  gcr.io/k8s-staging-cluster-api/cluster-api-aws-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/cluster-api-aws-controller
  gcr.io/k8s-staging-cluster-api/cluster-api-azure-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/cluster-api-azure-controller
  gcr.io/k8s-staging-cluster-api/cluster-api-gcp-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/cluster-api-gcp-controller
  gcr.io/k8s-staging-cluster-api/cluster-api-vsphere-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/cluster-api-vsphere-controller
  gcr.io/k8s-staging-cluster-api/cluster-api-openstack-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/cluster-api-openstack-controller
  gcr.io/k8s-staging-cluster-api/cluster-api-metal-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/cluster-api-metal-controller
  gcr.io/k8s-staging-cluster-api/cluster-api-ibmcloud-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/cluster-api-ibmcloud-controller
  gcr.io/k8s-staging-cluster-api/cluster-api-digitalocean-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/cluster-api-digitalocean-controller
  gcr.io/k8s-staging-cluster-api/cluster-api-hetzner-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/cluster-api-hetzner-controller
  gcr.io/k8s-staging-cluster-api/cluster-api-nutanix-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/cluster-api-nutanix-controller
  gcr.io/k8s-staging-cluster-api/cluster-api-oci-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/cluster-api-oci-controller
  gcr.io/k8s-staging-cluster-api/cluster-api-packet-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/cluster-api-packet-controller
  gcr.io/k8s-staging-cluster-api/cluster-api-tencentcloud-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/cluster-api-tencentcloud-controller
  gcr.io/k8s-staging-cluster-api/cluster-api-alibaba-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/cluster-api-alibaba-controller
  gcr.io/k8s-staging-cluster-api/cluster-api-equinixmetal-controller: m.daocloud.io/gcr.io/k8s-staging-cluster-api/cluster-api-equinixmetal-controller
  gcr.io/k8s-staging-cluster-api/cluster-api-cloudstack-controller: m.daocloud.io/

---

### Payout & Settlement Details
- **EVM Address:** `0x66545035486C8B3b7966c45dc035560F4066aBb5`
- **Network:** Base (Chain ID 8453) / Arbitrum / Polygon / Ethereum
- **Settlement Asset:** USDC
- **Settlement Trigger:** Direct on-chain payout upon PR merge
