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
@@ -30,6 +34,20 @@
     echo -e "${BLUE}[INFO]${NC} $1"
 }
 
+warn() {
+    echo -e "${YELLOW}[WARN]${NC} $1"
+}
+
+error() {
+    echo -e "${RED}[ERROR]${NC} $1"
+}
+
+success() {
+    echo -e "${GREEN}[OK]${NC} $1"
+}
+
+# ============================================
+# Logging
+# ============================================
 log() {
     echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${SCRIPT_DIR}/install.log"
 }
@@ -38,6 +56,7 @@
 # System Detection
 # ============================================
 detect_os() {
+    # shellcheck disable=SC1091
     if [[ -f /etc/os-release ]]; then
         . /etc/os-release
         OS=$ID
@@ -49,6 +68,7 @@
         OS_VERSION=$(sw_vers -productVersion)
     else
         OS="unknown"
+        OS_VERSION="unknown"
     fi
 }
 
@@ -56,6 +76,7 @@
 # Docker Installation
 # ============================================
 check_docker() {
+    # shellcheck disable=SC2034
     if command -v docker &> /dev/null; then
         DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
         info "Docker already installed: ${DOCKER_VERSION}"
@@ -65,6 +86,7 @@
 }
 
 install_docker() {
+    # shellcheck disable=SC2034
     if [[ "$DOCKER_INSTALLED" == "true" ]]; then
         info "Docker already installed, skipping..."
         return 0
@@ -73,6 +95,7 @@
     info "Installing Docker..."
     
     case $OS in
+        # shellcheck disable=SC1091
         ubuntu|debian)
             apt-get update
             apt-get install -y ca-certificates curl gnupg
@@ -84,6 +107,7 @@
             apt-get update
             apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
             ;;
+        # shellcheck disable=SC1091
         centos|rhel|fedora|rocky|almalinux)
             yum install -y yum-utils
             yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
@@ -108,6 +132,7 @@
 # Docker Compose Check
 # ============================================
 check_docker_compose() {
+    # shellcheck disable=SC2034
     if docker compose version &> /dev/null; then
         COMPOSE_VERSION=$(docker compose version | awk '{print $4}')
         info "Docker Compose v2 already installed: ${COMPOSE_VERSION}"
@@ -117,6 +142,7 @@
         COMPOSE_VERSION=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
         warn "Docker Compose v1 detected (${COMPOSE_VERSION}). Please upgrade to v2."
         warn "Run: sudo apt install docker-compose-plugin  (Debian/Ubuntu)"
+        warn "Or:  sudo yum install docker-compose-plugin   (RHEL/CentOS)"
         return 1
     else
         info "Docker Compose not found, will install with Docker..."
@@ -128,6 +154,7 @@
 # User Setup
 # ============================================
 setup_user() {
+    # shellcheck disable=SC2034
     if [[ "$EUID" -ne 0 ]]; then
         if ! groups "$USER" | grep -q '\bdocker\b'; then
             info "Adding user to docker group..."
@@ -143,6 +170,7 @@
 # Environment Setup
 # ============================================
 setup_env() {
+    # shellcheck disable=SC2034
     if [[ ! -f "${SCRIPT_DIR}/.env" ]]; then
         info "Creating .env from template..."
         cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
@@ -155,6 +183,7 @@
 # Directory Structure
 # ============================================
 setup_directories() {
+    # shellcheck disable=SC2034
     info "Creating directory structure..."
     
     mkdir -p "${SCRIPT_DIR}/data"
@@ -170,6 +199,7 @@
 # Stack Selection
 # ============================================
 select_stacks() {
+    # shellcheck disable=SC2034
     info "Available stacks:"
     
     local stacks=()
@@ -194,6 +224,7 @@
 # Port Check
 # ============================================
 check_ports() {
+    # shellcheck disable=SC2034
     info "Checking for port conflicts..."
     
     local ports=(80 443)
@@ -213,6 +244,7 @@
 # Main
 # ============================================
 main() {
+    # shellcheck disable=SC2034
     echo -e "${BOLD}🏠 HomeLab Stack Installer${NC}"
     echo "=========================="
     echo ""
@@ -235,6 +267,7 @@
     setup_directories
     
     # Select stacks
+    # shellcheck disable=SC2034
     select_stacks
     
     # Success
@@ -244,5 +277,6 @@
     echo ""
 }
 
+#!/usr/bin/env bash
 # Run main
 main "$@"
--- a/scripts/check-connectivity.sh
+++ b/scripts/check-connectivity.sh
@@ -0,0 +1,168 @@
+#!/usr/bin/env bash
+set -euo pipefail
+
+# ============================================
+# Network Connectivity Checker
+# ============================================
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+cd "$SCRIPT_DIR/.."
+
+# Colors
+RED='\033[0;31m'
+GREEN='\033[0;32m'
+YELLOW='\033[0;33m'
+BLUE='\033[0;34m'
+CYAN='\033[0;36m'
+BOLD='\