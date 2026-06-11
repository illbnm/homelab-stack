 ```diff
--- a/install.sh
+++ b/install.sh
@@ -1,12 +1,370 @@
 #!/usr/bin/env bash
-set -e
+set -euo pipefail
 
-echo "🏠 HomeLab Stack Installer"
-echo "============================"
+# HomeLab Stack Installer
+# Supports: Ubuntu/Debian/CentOS/Arch
+# Features: Docker install, port check, disk check, memory check, firewall check, retry logic
 
-# Placeholder installer
-# TODO: Add robust install logic
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+STACKS_DIR="${SCRIPT_DIR}/stacks"
 
-echo "✅ install.sh placeholder - implement me for the bounty!"
+# Colors
+RED='\033[0;31m'
+GREEN='\033[0;32m'
+YELLOW='\033[1;33m'
+BLUE='\033[0;34m'
+NC='\033[0m' # No Color
 
-exit 0
+info() { echo -e "${BLUE}[INFO]${NC} $*"; }
+warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
+error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
+success() { echo -e "${GREEN}[OK]${NC} $*"; }
+
+# Retry wrapper for curl
+curl_retry() {
+    local max_attempts=3
+    local delay=5
+    local attempt=1
+
+    while [[ $attempt -le $max_attempts ]]; do
+        if curl --connect-timeout 10 --max-time 60 --silent --show-error "$@"; then
+            return 0
+        fi
+        if [[ $attempt -lt $max_attempts ]]; then
+            warn "Attempt $attempt failed, retrying in ${delay}s..."
+            sleep "$delay"
+            delay=$((delay * 2))
+        fi
+        attempt=$((attempt + 1))
+    done
+    return 1
+}
+
+export -f curl_retry
+
+# Detect OS
+detect_os() {
+    if [[ -f /etc/os-release ]]; then
+        . /etc/os-release
+        echo "$ID"
+    else
+        echo "unknown"
+    fi
+}
+
+# Check if command exists
+command_exists() {
+    command -v "$1" >/dev/null 2>&1
+}
+
+# Install Docker on Ubuntu/Debian
+install_docker_debian() {
+    info "Installing Docker for Debian/Ubuntu..."
+    apt-get update
+    apt-get install -y ca-certificates curl gnupg lsb-release
+    install -m 0755 -d /etc/apt/keyrings
+    curl_retry -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || \
+        curl_retry -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
+    chmod a+r /etc/apt/keyrings/docker.gpg
+    echo \
+        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID \
+        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
+    apt-get update
+    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
+}
+
+# Install Docker on CentOS/RHEL/Fedora
+install_docker_centos() {
+    info "Installing Docker for CentOS/RHEL/Fedora..."
+    yum install -y yum-utils
+    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
+    yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
+    systemctl start docker
+    systemctl enable docker
+}
+
+# Install Docker on Arch
+install_docker_arch() {
+    info "Installing Docker for Arch Linux..."
+    pacman -Sy --noconfirm docker docker-compose
+    systemctl start docker
+    systemctl enable docker
+}
+
+# Install Docker
+install_docker() {
+    local os
+    os=$(detect_os)
+
+    case "$os" in
+        ubuntu|debian)
+            install_docker_debian
+            ;;
+        centos|rhel|fedora|rocky|almalinux)
+            install_docker_centos
+            ;;
+        arch|manjaro)
+            install_docker_arch
+            ;;
+        *)
+            error "Unsupported OS: $os. Please install Docker manually."
+            exit 1
+            ;;
+    esac
+}
+
+# Check Docker Compose version
+check_docker_compose() {
+    if command_exists docker-compose; then
+        warn "Docker Compose v1 detected (docker-compose). Please upgrade to Docker Compose v2 (docker compose plugin)."
+        warn "You can upgrade by running: docker compose version (to check) or reinstall Docker with the compose plugin."
+    fi
+
+    if ! docker compose version >/dev/null 2>&1; then
+        error "Docker Compose v2 plugin not found. Please install it."
+        exit 1
+    fi
+
+    success "Docker Compose v2 is installed: $(docker compose version --short 2>/dev/null || docker compose version)"
+}
+
+# Check port conflicts
+check_ports() {
+    local ports=(53 80 443 3000 3306 5432 6379 8080 8443 9000)
+    local conflicts=()
+
+    info "Checking for port conflicts..."
+    for port in "${ports[@]}"; do
+        if ss -tlnp 2>/dev/null | grep -q ":$port "; then
+            conflicts+=("$port")
+        fi
+    done
+
+    if [[ ${#conflicts[@]} -gt 0 ]]; then
+        warn "Port conflicts detected on: ${conflicts[*]}"
+        warn "These ports may be used by existing services. Please free them or adjust your compose files."
+    else
+        success "No common port conflicts detected"
+    fi
+}
+
+# Check disk space
+check_disk() {
+    local available
+    available=$(df -BG . | awk 'NR==2 {print $4}' | tr -d 'G')
+
+    if [[ "$available" -lt 5 ]]; then
+        error "Insufficient disk space: ${available}GB available. At least 5GB is required."
+        exit 1
+   