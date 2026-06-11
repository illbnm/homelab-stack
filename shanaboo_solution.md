 ```diff
--- a/install.sh
+++ b/install.sh
@@ -1,4 +1,4 @@
-#!/bin/bash
+#!/usr/bin/env bash
 set -euo pipefail
 
 # ============================================
@@ -6,6 +6,8 @@
 # ============================================
 
 SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+CONFIG_DIR="${SCRIPT_DIR}/config"
+SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
 
 # Colors
 RED='\033[0;31m'
@@ -14,6 +16,7 @@
 BLUE='\033[0;34m'
 CYAN='\033[0;36m'
 NC='\033[0m' # No Color
+BOLD='\033[1m'
 
 # Logging
 log_info() {
@@ -29,6 +32,16 @@
     echo -e "${RED}[ERROR]${NC} $1" >&2
 }
 
+log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
 }
 
+# ============================================
+# Utility Functions
+# ============================================
+
+# Retry wrapper with exponential backoff
+curl_retry() {
+    local max_attempts=3
+    local delay=5
+    local i
+    for i in $(seq 1 $max_attempts); do
+        if curl --connect-timeout 10 --max-time 60 "$@"; then
+            return 0
+        fi
+        if [ "$i" -lt "$max_attempts" ]; then
+            log_warn "Attempt $i failed, retrying in ${delay}s..."
+            sleep "$delay"
+            delay=$((delay * 2))
+        fi
+    done
+    return 1
+}
+
+# Check if command exists
+command_exists() {
+    command -v "$1" >/dev/null 2>&1
+}
+
+# Detect OS
+detect_os() {
+    if [ -f /etc/os-release ]; then
+        # shellcheck source=/dev/null
+        . /etc/os-release
+        echo "$ID"
+    else
+        echo "unknown"
+    fi
+}
+
+# ============================================
+# Pre-flight Checks
+# ============================================
+
+check_root() {
+    if [ "$EUID" -eq 0 ]; then
+        return 0
+    fi
+    return 1
+}
+
+check_docker_group() {
+    if id -nG "$USER" | grep -qw "docker"; then
+        return 0
+    fi
+    return 1
+}
+
+check_disk_space() {
+    local available
+    available=$(df -BG "$SCRIPT_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
+    if [ "$available" -lt 5 ]; then
+        log_error "Insufficient disk space: ${available}GB available. At least 5GB required."
+        exit 1
+    elif [ "$available" -lt 20 ]; then
+        log_warn "Low disk space: ${available}GB available. Recommended: 20GB+"
+    else
+        log_info "Disk space: ${available}GB available"
+    fi
+}
+
+check_memory() {
+    local mem_gb
+    mem_gb=$(free -g | awk '/^Mem:/{print $2}')
+    if [ "$mem_gb" -lt 2 ]; then
+        log_warn "Low memory: ${mem_gb}GB. Recommended: 2GB+"
+    else
+        log_info "Memory: ${mem_gb}GB"
+    fi
+}
+
+check_ports() {
+    local ports=(53 80 443 3000 8080 8443)
+    local port_in_use=false
+    for port in "${ports[@]}"; do
+        if ss -tlnp | awk '{print $4}' | grep -q ":${port}\$"; then
+            log_warn "Port $port is already in use"
+            port_in_use=true
+        fi
+    done
+    if [ "$port_in_use" = true ]; then
+        log_warn "Some required ports are in use. This may cause conflicts."
+    fi
+}
+
+check_firewall() {
+    if command_exists ufw && ufw status | grep -q "Status: active"; then
+        log_warn "UFW firewall is active. Ensure required ports are open."
+    fi
+    if command_exists firewall-cmd && systemctl is-active --quiet firewalld 2>/dev/null; then
+        log_warn "firewalld is active. Ensure required ports are open."
+    fi
+}
+
+# ============================================
+# Docker Installation
+# ============================================
+
+install_docker_ubuntu_debian() {
+    log_info "Installing Docker for Ubuntu/Debian..."
+    apt-get update
+    apt-get install -y ca-certificates curl gnupg lsb-release
+    install -m 0755 -d /etc/apt/keyrings
+    curl_retry -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc 2>/dev/null || \
+        curl_retry -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc 2>/dev/null
+    chmod a+r /etc/apt/keyrings/docker.asc
+    echo \
+        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
+        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
+        tee /etc/apt/sources.list.d/docker.list > /dev/null
+    apt-get update
+    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
+}
+
+install_docker_centos() {
+    log_info "Installing Docker for CentOS..."
+    yum install -y yum-utils
+    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
+    yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
+    systemctl start docker
+    systemctl enable docker
+}
+
+install_docker_arch() {
+    log_info "Installing Docker for Arch Linux..."
+    pacman -Sy --noconfirm docker docker-compose
+    systemctl start docker
+    systemctl enable docker
+}
+
+install_docker() {
+    log_info "Docker not found. Installing..."
+    local os_id
+    os_id=$(detect_os)
+    case "$os_id" in
+        ubuntu|debian)
+            install_docker_ubuntu_debian
