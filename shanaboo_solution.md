 ```diff
--- /dev/null
+++ b/stacks/network/docker-compose.yml
@@ -0,0 +1,120 @@
+version: "3.8"
+
+services:
+  # AdGuard Home - DNS filter + ad blocker
+  adguardhome:
+    image: adguard/adguardhome:v0.107.52
+    container_name: adguardhome
+    restart: unless-stopped
+    ports:
+      - "53:53/tcp"
+      - "53:53/udp"
+      - "3000:3000/tcp"  # Initial setup web UI
+      - "80:80/tcp"       # Web UI after setup (or use 8080)
+    volumes:
+      - ./adguardhome/work:/opt/adguardhome/work
+      - ./adguardhome/conf:/opt/adguardhome/conf
+    environment:
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
+    dns:
+      - 127.0.0.1
+      - 1.1.1.1
+
+  # Unbound - Recursive DNS resolver
+  unbound:
+    image: mvance/unbound:1.21.1
+    container_name: unbound
+    restart: unless-stopped
+    ports:
+      - "5053:53/tcp"
+      - "5053:53/udp"
+    volumes:
+      - ./unbound:/opt/unbound/etc/unbound
+    environment:
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
+
+  # WireGuard Easy - VPN server with Web UI
+  wg-easy:
+    image: ghcr.io/wg-easy/wg-easy:14
+    container_name: wg-easy
+    restart: unless-stopped
+    cap_add:
+      - NET_ADMIN
+      - SYS_MODULE
+    sysctls:
+      - net.ipv4.conf.all.src_valid_mark=1
+      - net.ipv4.ip_forward=1
+      - net.ipv6.conf.all.forwarding=1
+    ports:
+      - "51820:51820/udp"
+      - "51821:51821/tcp"  # Web UI
+    volumes:
+      - ./wg-easy:/etc/wireguard
+    environment:
+      - WG_HOST=${WG_HOST:-your-domain.com}
+      - PASSWORD_HASH=${WG_PASSWORD_HASH:-}
+      - WG_DEFAULT_DNS=adguardhome  # Point to AdGuard Home
+      - WG_PERSISTENT_KEEPALIVE=25
+      - WG_DEFAULT_ADDRESS=10.8.0.x
+      - WG_ALLOWED_IPS=0.0.0.0/0,::/0
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
+    depends_on:
+      - adguardhome
+
+  # Cloudflare DDNS - Dynamic DNS updater
+  cloudflare-ddns:
+    image: ghcr.io/favonia/cloudflare-ddns:1.14.0
+    container_name: cloudflare-ddns
+    restart: unless-stopped
+    environment:
+      - CF_API_TOKEN=${CF_API_TOKEN}
+      - DOMAINS=${CF_DOMAINS}
+      - PROXIED=${CF_PROXIED:-false}
+      - TZ=${TZ:-UTC}
+      # IPv4 + IPv6 dual stack
+      - IP4_PROVIDER=cloudflare
+      - IP6_PROVIDER=cloudflare
+      # Update interval (default 5 minutes)
+      - UPDATE_CRON=*/5 * * * *
+      # Delete stale records
+      - DELETE_ON_STOP=true
+      # Grace period for DNS propagation
+      - TTL=1
+    networks:
+      - network
+
+  # Nginx Proxy Manager - Reverse proxy with Web UI
+  nginx-proxy-manager:
+    image: jc21/nginx-proxy-manager:latest
+    container_name: nginx-proxy-manager
+    restart: unless-stopped
+    ports:
+      - "81:81/tcp"    # Web UI
+      - "443:443/tcp"  # HTTPS
+    volumes:
+      - ./nginx-proxy-manager/data:/data
+      - ./nginx-proxy-manager/letsencrypt:/etc/letsencrypt
+    environment:
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
+
+networks:
+  network:
+    name: network
+    driver: bridge
+
--- /dev/null
+++ b/stacks/network/.env.example
@@ -0,0 +1,23 @@
+# WireGuard
+WG_HOST=wg.your-domain.com
+WG_PASSWORD_HASH=$$2y$$10$$... # bcrypt hash of your password
+
+# Cloudflare DDNS
+CF_API_TOKEN=your-cloudflare-api-token
+CF_DOMAINS=example.com,*.example.com
+CF_PROXIED=false
+
+# Timezone
+TZ=Asia/Shanghai
+
+# AdGuard Home initial setup
+# After first run, configure upstream DNS to: unbound:53
+# Or use DoH/DoT: https://dns.cloudflare.com/dns-query, tls://dns.google
+
+# WireGuard DNS will point to AdGuard Home (10.8.0.1 or container IP)
+# For split tunneling, set WG_ALLOWED_IPS to your home network range
+# Example: WG_ALLOWED_IPS=192.168.1.0/24,10.8.0.0/24
+
+# Nginx Proxy Manager
+# Default login: admin@example.com / changeme
+# Change after first login at http://your-ip:81
--- /dev/null
+++ b/stacks/network/scripts/fix-dns-port.sh
@@ -0,0 +1,95 @@
+#!/bin/bash
+#
+# fix-dns-port.sh - Detect and resolve systemd-resolved port 53 conflicts
+# Usage: ./fix-dns-port.sh [--check|--apply|--restore]
+#
+
+set -euo pipefail
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+BACKUP_DIR="${SCRIPT_DIR}/../backups"
+RESOLVED_CONF="/etc/systemd/resolved.conf"
+RESOLVED_CONF_D="/etc/systemd/resolved.conf.d"
+
+# Colors for output
+RED='\033[0;31m'
+GREEN='\033[0;32m'
+YELLOW='\033[1;33m'
+NC='\033[0m' # No Color
+
+log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
+log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
+log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
+
+check_systemd_resolved