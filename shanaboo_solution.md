 ```diff
--- a/install.sh
+++ b/install.sh
@@ -1,4 +1,4 @@
-#!/bin/bash
+#!/usr/bin/env bash
 set -euo pipefail
 
 # HomeLab Stack - Install Script
@@ -6,6 +6,9 @@
 
 SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
 
+# Source shared utilities
+source "${SCRIPT_DIR}/scripts/lib/common.sh" 2>/dev/null || true
+
 # Colors
 RED='\033[0;31m'
 GREEN='\033[0;32m'
@@ -13,6 +16,7 @@
 BLUE='\033[0;34m'
 YELLOW='\033[1;33m'
 NC='\033[0m' # No Color
+BOLD='\033[1m'
 
 log_info() {
   echo -e "${BLUE}[INFO]${NC} $1"
@@ -30,6 +34,10 @@
   echo -e "${RED}[ERROR]${NC} $1"
 }
 
+log_warn() {
+  echo -e "${YELLOW}[WARN]${NC} $1"
+}
+
 check_command() {
   command -v "$1" >/dev/null 2>&1
 }
@@ -38,6 +46,7 @@
   local max_attempts=3
   local delay=5
   local i
+
   for i in $(seq 1 $max_attempts); do
     curl --connect-timeout 10 --max-time 60 "$@" && return 0
     if [ "$i" -lt "$max_attempts" ]; then
@@ -49,6 +58,7 @@
   return 1
 }
 
+# Detect OS
 detect_os() {
   if [ -f /etc/os-release ]; then
     # shellcheck source=/dev/null
@@ -61,6 +71,7 @@
   fi
 }
 
+# Install Docker based on OS
 install_docker() {
   local os="$1"
   log_info "Installing Docker for $os..."
@@ -68,7 +79,7 @@
   case "$os" in
     ubuntu|debian)
       apt-get update
-      apt-get install -y ca-certificates curl gnupg lsb-release
+      apt-get install -y ca-certificates curl gnupg lsb-release software-properties-common
       mkdir -p /etc/apt/keyrings
       curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || \
         curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
@@ -77,6 +88,7 @@
         $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
       apt-get update
       apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
+      systemctl enable --now docker
       ;;
     centos|rhel|fedora|rocky|almalinux)
       if [ "$os" = "fedora" ]; then
@@ -90,6 +102,7 @@
         systemctl start docker
         systemctl enable docker
       fi
+      systemctl enable --now docker
       ;;
     arch|manjaro)
       pacman -Sy --noconfirm docker docker-compose
@@ -101,6 +114,7 @@
   esac
 }
 
+# Check and upgrade Docker Compose v1 to v2
 check_docker_compose() {
   if check_command docker-compose; then
     if ! docker compose version >/dev/null 2>&1; then
@@ -113,6 +127,7 @@
   fi
 }
 
+# Check port conflicts
 check_ports() {
   local ports=(53 80 443 3000 3306 5432 6379 8080 8443)
   local in_use=()
@@ -130,6 +145,7 @@
   fi
 }
 
+# Check disk space
 check_disk_space() {
   local available
   available=$(df -BG "$SCRIPT_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
@@ -143,6 +159,7 @@
   fi
 }
 
+# Check memory
 check_memory() {
   local mem_total
   mem_total=$(free -m | awk '/^Mem:/{print $2}')
@@ -153,6 +170,7 @@
   fi
 }
 
+# Check firewall
 check_firewall() {
   if check_command ufw; then
     log_info "UFW detected. Ensure required ports are open."
@@ -162,6 +180,7 @@
   fi
 }
 
+# Add user to docker group
 setup_user() {
   if [ "$EUID" -ne 0 ]; then
     if ! groups "$USER" | grep -q '\bdocker\b'; then
@@ -174,6 +193,7 @@
   fi
 }
 
+# Main install function
 main() {
   log_info "Starting HomeLab Stack installation..."
 
@@ -181,6 +201,7 @@
   local os
   os=$(detect_os)
   log_info "Detected OS: $os"
+  export DETECTED_OS="$os"
 
   # Check Docker
   if ! check_command docker; then
@@ -213,6 +234,7 @@
   # Setup user
   setup_user
 
+  # Create .env if not exists
   if [ ! -f "$SCRIPT_DIR/.env" ]; then
     log_info "Creating .env from example..."
     cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
@@ -222,6 +244,7 @@
   log_info "Installation complete!"
   log_info "Run 'docker compose -f docker-compose.base.yml up -d' to start base services."
   log_info "For China users, run './scripts/setup-cn-mirrors.sh' first."
+  log_info "Run './scripts/check-connectivity.sh' to verify network connectivity."
 }
 
 main "$@"
--- /dev/null
+++ b/config/cn-mirrors.yml
@@ -0,0 +1,28 @@
+# CN Mirror mappings for gcr.io / ghcr.io images
+# Format: original: mirror
+
+mirrors:
+  # gcr.io mirrors
+  gcr.io/cadvisor/cadvisor: m.daocloud.io/gcr.io/cadvisor/cadvisor
+  gcr.io/google-containers/pause: m.daocloud.io/gcr.io/google-containers/pause
+
+  # ghcr.io mirrors
+  ghcr.io/goauthentik/server: m.daocloud.io/ghcr.io/goauthentik/server
+  ghcr.io/home-assistant/home-assistant: m.daocloud.io/ghcr.io/home-assistant/home-assistant
+ 