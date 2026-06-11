 ```diff
--- a/install.sh
+++ b/install.sh
@@ -1,4 +1,4 @@
-#!/bin/bash
+#!/usr/bin/env bash
 #
 # HomeLab Stack - One-click installer
 # Supports: Ubuntu/Debian, CentOS/RHEL, Arch Linux
@@ -6,6 +6,9 @@
 
 set -euo pipefail
 
+# shellcheck disable=SC2155
+readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+
 # Colors
 RED='\033[0;31m'
 GREEN='\033[0;32m'
@@ -13,6 +16,7 @@
 BLUE='\033[0;34m'
 CYAN='\033[0;36m'
 NC='\033[0m' # No Color
+BOLD='\033[1m'
 
 # Logging
 log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
@@ -20,6 +24,30 @@
 log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
 log_step() { echo -e "${BLUE}[STEP]${NC} $*"; }
 
+# Retry wrapper for network requests
+curl_retry() {
+  local max_attempts=3
+  local delay=5
+  local i
+  for i in $(seq 1 $max_attempts); do
+    if curl --connect-timeout 10 --max-time 60 -s "$@"; then
+      return 0
+    fi
+    if [ "$i" -lt "$max_attempts" ]; then
+      log_warn "Attempt $i failed, retrying in ${delay}s..."
+      sleep "$delay"
+      delay=$((delay * 2))
+    fi
+  done
+  return 1
+}
+
+# Check if command exists
+command_exists() {
+  command -v "$1" >/dev/null 2>&1
+}
+
+# ==============================================================================
+# Docker Installation
+# ==============================================================================
+
 check_docker() {
   if command -v docker &>/dev/null; then
     log_info "Docker found: $(docker --version)"
@@ -29,6 +57,7 @@
   fi
 }
 
+# Legacy: kept for compatibility, install.sh now handles this inline
 install_docker() {
   log_step "Installing Docker..."
   # Detect OS and install accordingly
@@ -36,6 +65,7 @@
     . /etc/os-release
     case "$ID" in
       ubuntu|debian)
+        log_info "Detected $ID, installing Docker via official repo..."
         apt-get update
         apt-get install -y ca-certificates curl gnupg
         install -m 0755 /etc/apt/keyrings /etc/apt/keyrings 2>/dev/null || true
@@ -44,6 +74,7 @@
         apt-get update
         apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
         ;;
+
       centos|rhel|fedora|rocky|almalinux)
         if [ "$ID" = "fedora" ]; then
           dnf -y install dnf-plugins-core
@@ -55,6 +86,7 @@
           systemctl start docker
         fi
         ;;
+
       arch|manjaro)
         pacman -Sy --noconfirm docker docker-compose
         systemctl enable docker
@@ -69,6 +101,7 @@
   fi
 }
 
+# Legacy: kept for compatibility
 check_docker_compose() {
   if docker compose version &>/dev/null; then
     log_info "Docker Compose v2 found"
@@ -80,6 +113,7 @@
   fi
 }
 
+# Legacy: kept for compatibility
 create_env_file() {
   if [ ! -f .env ]; then
     log_step "Creating .env file..."
@@ -91,6 +125,7 @@
   fi
 }
 
+# Legacy: kept for compatibility
 start_base() {
   log_step "Starting base infrastructure..."
   if [ -f docker-compose.base.yml ]; then
@@ -100,6 +135,7 @@
   fi
 }
 
+# Legacy: kept for compatibility
 print_banner() {
   echo -e "${CYAN}"
   cat << 'EOF'
@@ -112,6 +148,7 @@
   echo -e "${NC}"
 }
 
+# Legacy: kept for compatibility
 print_next_steps() {
   echo ""
   log_info "Installation complete!"
@@ -122,6 +159,7 @@
   echo ""
 }
 
+# Legacy: kept for compatibility
 check_ports() {
   local ports=(80 443 3000 8080 9000)
   for port in "${ports[@]}"; do
@@ -134,6 +172,7 @@
   done
 }
 
+# Legacy: kept for compatibility
 check_disk_space() {
   local available
   available=$(df -BG . | awk 'NR==2 {print $4}' | tr -d 'G')
@@ -146,6 +185,7 @@
   fi
 }
 
+# Legacy: kept for compatibility
 check_memory() {
   local mem
   mem=$(free -m | awk '/^Mem:/{print $2}')
@@ -156,6 +196,7 @@
   fi
 }
 
+# Legacy: kept for compatibility
 check_firewall() {
   if command -v ufw &>/dev/null; then
     log_info "UFW firewall detected. Ensure required ports are open."
@@ -164,6 +205,7 @@
   fi
 }
 
+# Legacy: kept for compatibility
 add_user_to_docker_group() {
   if [ "$EUID" -ne 0 ]; then
     if ! groups "$USER" | grep -q '\bdocker\b'; then
@@ -175,6 +217,7 @@
   fi
 }
 
+# Legacy: kept for compatibility
 setup_cn_mirrors() {
   if [ "${SETUP_CN_MIRRORS:-false}" = "true" ]; then
     log_step "Setting up CN mirrors..."
@@ -184,6 +227,7 @@
   fi
 }
 
+# Legacy: kept for compatibility
 main() {
   print_banner
   check_docker
@@ -199,5 +243,250 @@
   print_next_steps
 }
 
+# ==============================================================================
+# New robust install.sh implementation
+# ==============================================================================
+
+check_root_or_docker_group() {
+  if [ "$EUID" -eq 0 ]; then
+    return 0
+  fi
+  if groups "$USER" 2>/dev/null | grep -q '\bdocker\b'; then
+    return 0
+  fi
+  log_warn "Current user is not in the docker group. Some operations may fail."
+  return 1
+}
+
+auto_install_docker() {
+  if command_exists docker; then
+    log_info "Docker already installed: $(