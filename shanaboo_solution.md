```diff
--- a/install.sh
+++ b/install.sh
@@ -1,4 +1,4 @@
-#!/bin/bash
+#!/usr/bin/env bash
 set -euo pipefail
 
 # ============================================
@@ -6,6 +6,9 @@
 # ============================================
 
 SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+REQUIRED_PORTS=(53 80 443 3000 8080 8443)
+MIN_DISK_GB=20
+CRITICAL_DISK_GB=5
 
 # Colors
 RED='\033[0;31m'
@@ -14,6 +17,7 @@
 BLUE='\033[0;34m'
 CYAN='\033[0;36m'
 BOLD='\033[1m'
+YELLOW='\033[0;33m'
 NC='\033[0m' # No Color
 
 # ============================================
@@ -28,6 +32,16 @@
     echo -e "${RED}❌ $1${NC}"
 }
 
+warn() {
+    echo -e "${YELLOW}⚠️  $1${NC}"
+}
+
+info() {
+    echo -e "${BLUE}ℹ️  $1${NC}"
+}
+
+# ============================================
+# Progress
+# ============================================
 spinner() {
     local pid=$1
     local delay=0.1
@@ -40,6 +54,36 @@
     printf "    \b\b\b\b"
 }
 
+# ============================================
+# Retry wrapper with exponential backoff
+# ============================================
+curl_retry() {
+    local max_attempts=3
+    local delay=5
+    local attempt=1
+
+    while [[ $attempt -le $max_attempts ]]; do
+        if curl --connect-timeout 10 --max-time 60 --silent --show-error "$@"; then
+            return 0
+        fi
+
+        if [[ $attempt -eq $max_attempts ]]; then
+            error "All $max_attempts attempts(s) failed for: curl $*"
+            return 1
+        fi
+
+        warn "Attempt $attempt failed, retrying in ${delay}s..."
+        sleep "$delay"
+        delay=$((delay * 2))
+        attempt=$((attempt + 1))
+    done
+}
+
+# Also wrap wget if used
+wget_retry() {
+    local max_attempts=3
+    local delay=5
+    for i in $(seq 1 $max_attempts); do
+        wget --timeout=60 "$@" && return 0
+        warn "wget attempt $i failed, retrying in ${delay}s..."
+        sleep $delay
+        delay=$((delay * 2))
+    done
+    return 1
+}
+
 # ============================================
 # Check if command exists
 # ============================================
@@ -47,6 +93,15 @@
     command -v "$1" >/dev/null 2>&1
 }
 
+# ============================================
+# Detect OS
+# ============================================
+detect_os() {
+    if [[ -f /etc/os-release ]]; then
+        . /etc/os-release
+        echo "$ID"
+    fi
+}
+
 # ============================================
 # Check Docker
 # ============================================
@@ -55,6 +110,7 @@
         error "Docker is not installed."
         return 1
     fi
+
     if ! docker info >/dev/null 2>&1; then
         error "Docker daemon is not running or you don't have permission."
         return 1
@@ -62,6 +118,93 @@
     return 0
 }
 
+# ============================================
+# Install Docker
+# ============================================
+install_docker() {
+    local os
+    os=$(detect_os)
+
+    case "$os" in
+        ubuntu|debian)
+            info "Installing Docker for Debian/Ubuntu..."
+            apt-get update
+            apt-get install -y ca-certificates curl gnupg lsb-release
+            install -m 0755 -d /etc/apt/keyrings
+            curl -fsSL https://download.docker.com/linux/$os/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
+            chmod a+r /etc/apt/keyrings/docker.gpg
+            echo \
+                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$os \
+                $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
+            apt-get update
+            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
+            ;;
+        centos|rhel|fedora|rocky|almalinux)
+            info "Installing Docker for RHEL/CentOS/Fedora..."
+            dnf -y install dnf-plugins-core
+            dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
+            dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
+            systemctl start docker
+            systemctl enable docker
+            ;;
+        arch|manjaro)
+            info "Installing Docker for Arch..."
+            pacman -Sy --noconfirm docker docker-compose
+            systemctl start docker
+            systemctl enable docker
+            ;;
+        *)
+            error "Unsupported OS: $os. Please install Docker manually."
+            exit 1
+            ;;
+    esac
+}
+
+# ============================================
+# Check Docker Compose version
+# ============================================
+check_docker_compose() {
+    if docker compose version >/dev/null 2>&1; then
+        success "Docker Compose v2 is available"
+        return 0
+    elif docker-compose version >/dev/null 2>&1; then
+        warn "Docker Compose v1 detected. Please upgrade to v2 for better compatibility."
+        warn "Run: sudo apt-get install docker-compose-plugin  (Debian/Ubuntu)"
+        warn "Or:  sudo dnf install docker-compose-plugin     (RHEL/CentOS)"
+        return 1
+    else
+        error "Docker Compose is not installed."
+        return 1
+    fi
+}
+
+# ============================================
+# Check port conflicts
+# ============================================
+check_ports() {
+    local conflicts=()
+    for port in "${REQUIRED_PORTS[@]}"; do
+        if command -v ss >/dev/null 2>&1; then
+            if ss -tlnp | awk '{print $4}' | grep -q ":$port\$"; then
+                conflicts+=("$port")
+            fi
+        elif command -v netstat >/dev/null 2>&1; then
+            if netstat