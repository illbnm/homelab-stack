 ```diff
--- a/install.sh
+++ b/install.sh
@@ -1,3 +1,4 @@
+#!/usr/bin/env bash
 #!/bin/bash
 set -euo pipefail
 
@@ -5,6 +6,8 @@
 # HomeLab Stack - One-click Installer
 # ============================================
 
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+
 # Colors
 RED='\033[0;31m'
 GREEN='\033[0;32m'
@@ -12,6 +15,7 @@
 BLUE='\033[0;34m'
 YELLOW='\033[1;33m'
 NC='\033[0m' # No Color
+BOLD='\033[1m'
 
 # Logging
 log_info() {
@@ -30,6 +34,248 @@
     echo -e "${RED}[ERROR]${NC} $1" >&2
 }
 
+# ============================================
+# Retry wrapper for network requests
+# ============================================
+curl_retry() {
+    local max_attempts=3
+    local delay=5
+    local attempt=1
+    for ((attempt=1; attempt<=max_attempts; attempt++)); do
+        if curl --connect-timeout 10 --max-time 60 -s "$@"; then
+            return 0
+        fi
+        if [[ $attempt -lt $max_attempts ]]; then
+            log_warn "Attempt $attempt failed, retrying in ${delay}s..."
+            sleep "$delay"
+            delay=$((delay * 2))
+        fi
+    done
+    return 1
+}
+
+# ============================================
+# System checks
+# ============================================
+check_disk_space() {
+    local available
+    available=$(df -BG . | awk 'NR==2 {print $4}' | tr -d 'G')
+    if [[ -z "$available" || ! "$available" =~ ^[0-9]+$ ]]; then
+        available=$(df -k . | awk 'NR==2 {print $4}')
+        available=$((available / 1024 / 1024))
+    fi
+    if [[ "$available" -lt 5 ]]; then
+        log_error "磁盘空间不足: ${available}GB 可用，至少需要 5GB"
+        exit 1
+    elif [[ "$available" -lt 20 ]]; then
+        log_warn "磁盘空间警告: ${available}GB 可用，建议至少 20GB"
+    else
+        log_info "磁盘空间: ${available}GB 可用"
+    fi
+}
+
+check_memory() {
+    local mem_mb
+    mem_mb=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo "0")
+    if [[ "$mem_mb" -lt 2048 ]]; then
+        log_warn "内存不足: ${mem_mb}MB，建议至少 2GB"
+    else
+        log_info "内存: ${mem_mb}MB"
+    fi
+}
+
+check_ports() {
+    local ports=(53 80 443 3000 3306 5432 6379 8080 8443)
+    local in_use=()
+    for port in "${ports[@]}"; do
+        if command -v ss &>/dev/null; then
+            if ss -tlnp 2>/dev/null | grep -q ":$port\b"; then
+                in_use+=("$port")
+            fi
+        elif command -v netstat &>/dev/null; then
+            if netstat -tlnp 2>/dev/null | grep -q ":$port\b"; then
+                in_use+=("$port")
+            fi
+        fi
+    done
+    if [[ ${#in_use[@]} -gt 0 ]]; then
+        log_warn "端口已被占用: ${in_use[*]}"
+    fi
+}
+
+check_firewall() {
+    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
+        log_warn "ufw 防火墙已启用，请确保必要端口已开放"
+    fi
+    if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
+        log_warn "firewalld 防火墙已启用，请确保必要端口已开放"
+    fi
+}
+
+# ============================================
+# Docker installation
+# ============================================
+install_docker_ubuntu() {
+    log_info "Installing Docker for Ubuntu/Debian..."
+    apt-get update
+    apt-get install -y ca-certificates curl gnupg lsb-release
+    install -m 0755 -d /etc/apt/keyrings
+    curl_retry -fsSL "https://download.docker.com/linux/ubuntu/gpg" -o /tmp/docker.gpg || \
+        curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" -o /tmp/docker.gpg
+    gpg --dearmor -o /etc/apt/keyrings/docker.gpg /tmp/docker.gpg
+    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
+    apt-get update
+    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
+}
+
+install_docker_debian() {
+    log_info "Installing Docker for Debian..."
+    apt-get update
+    apt-get install -y ca-certificates curl gnupg lsb-release
+    install -m 0755 -d /etc/apt/keyrings
+    curl_retry -fsSL "https://download.docker.com/linux/debian/gpg" -o /tmp/docker.gpg || \
+        curl -fsSL "https://download.docker.com/linux/debian/gpg" -o /tmp/docker.gpg
+    gpg --dearmor -o /etc/apt/keyrings/docker.gpg /tmp/docker.gpg
+    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
+    apt-get update
+    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
+}
+
+install_docker_centos() {
+    log_info "Installing Docker for CentOS/RHEL..."
+    yum install -y yum-utils
+    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || \
+        curl -fsSL https://download.docker.com/linux/centos/docker