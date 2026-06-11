 ```diff
--- /dev/null
+++ b/stacks/network/docker-compose.yml
@@ -0,0 +1,120 @@
+version: "3.8"
+
+networks:
+  network:
+    name: network
+    driver: bridge
+
+services:
+  # AdGuard Home - DNS filter + ad blocker
+  adguard-home:
+    image: adguard/adguardhome:v0.107.52
+    container_name: adguard-home
+    restart: unless-stopped
+    ports:
+      - "53:53/tcp"
+      - "53:53/udp"
+      - "3000:3000/tcp"  # Initial setup web UI
+    volumes:
+      - ./config/adguard-home/work:/opt/adguardhome/work
+      - ./config/adguard-home/conf:/opt/adguardhome/conf
+    networks:
+      - network
+    environment:
+      - TZ=${TZ:-UTC}
+    cap_add:
+      - NET_ADMIN
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
+      - ./config/unbound:/opt/unbound/etc/unbound
+    networks:
+      - network
+    environment:
+      - TZ=${TZ:-UTC}
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
+      - net.ipv6.conf.all.disable_ipv6=0
+      - net.ipv6.conf.all.forwarding=1
+    ports:
+      - "51820:51820/udp"
+      - "51821:51821/tcp"  # Web UI
+    volumes:
+      - ./config/wg-easy:/etc/wireguard
+    networks:
+      - network
+    environment:
+      - WG_HOST=${WG_HOST:-vpn.example.com}
+      - PASSWORD_HASH=${WG_PASSWORD_HASH:-}
+      - WG_DEFAULT_DNS=adguard-home
+      - WG_PERSISTENT_KEEPALIVE=25
+      - WG_DEFAULT_ADDRESS=10.8.0.x
+      - WG_ALLOWED_IPS=0.0.0.0/0,::/0
+      - WG_MTU=1420
+      - UI_TRAFFIC_STATS=true
+      - UI_CHART_TYPE=2
+      - TZ=${TZ:-UTC}
+    depends_on:
+      - adguard-home
+
+  # Cloudflare DDNS - Dynamic DNS updater
+  cloudflare-ddns:
+    image: ghcr.io/favonia/cloudflare-ddns:1.14.0
+    container_name: cloudflare-ddns
+    restart: unless-stopped
+    networks:
+      - network
+    environment:
+      - CF_API_TOKEN=${CF_API_TOKEN}
+      - DOMAINS=${CF_DOMAINS}
+      - PROXIED=${CF_PROXIED:-false}
+      - IP6_PROVIDER=${CF_IP6_PROVIDER:-none}
+      - TZ=${TZ:-UTC}
+    depends_on:
+      - adguard-home
+
+  # Nginx Proxy Manager - Reverse proxy with Web UI
+  nginx-proxy-manager:
+    image: jc21/nginx-proxy-manager:latest
+    container_name: nginx-proxy-manager
+    restart: unless-stopped
+    ports:
+      - "80:80"
+      - "443:443"
+      - "81:81"  # Admin UI
+    volumes:
+      - ./config/nginx-proxy-manager/data:/data
+      - ./config/nginx-proxy-manager/letsencrypt:/etc/letsencrypt
+    networks:
+      - network
+    environment:
+      - TZ=${TZ:-UTC}
+    depends_on:
+      - adguard-home
--- /dev/null
+++ b/stacks/network/.env.example
@@ -0,0 +1,23 @@
+# Timezone
+TZ=Asia/Shanghai
+
+# WireGuard Easy
+WG_HOST=vpn.example.com
+WG_PASSWORD_HASH=$$2a$$12$$LQv/aBzJ9jKS9DP5q8XuOe0y1z2y3z4y5z6y7z8y9z0y1z2y3z4y5z6
+# Generate with: docker run ghcr.io/wg-easy/wg-easy wgpw 'yourpassword'
+WG_DEFAULT_DNS=10.8.0.1
+
+# Cloudflare DDNS
+CF_API_TOKEN=your_cloudflare_api_token
+CF_DOMAINS=example.com,*.example.com
+CF_PROXIED=false
+CF_IP6_PROVIDER=none
+
+# Nginx Proxy Manager
+DB_MYSQL_HOST=npm-db
+DB_MYSQL_PORT=3306
+DB_MYSQL_USER=npm
+DB_MYSQL_PASSWORD=npm_password
+DB_MYSQL_NAME=npm
+
+# AdGuard Home initial admin password (set via web UI at :3000)
--- /dev/null
+++ b/stacks/network/scripts/fix-dns-port.sh
@@ -0,0 +1,89 @@
+#!/bin/bash
+
+# fix-dns-port.sh - Detect and disable systemd-resolved port 53 conflict
+# Usage: ./fix-dns-port.sh [--check|--apply|--restore]
+
+set -euo pipefail
+
+RESOLVED_CONF="/etc/systemd/resolved.conf"
+RESOLVED_BACKUP="/etc/systemd/resolved.conf.backup.$(date +%Y%m%d%H%M%S)"
+
+show_help() {
+    echo "Usage: $(basename "$0") [OPTION]"
+    echo ""
+    echo "Options:"
+    echo "  --check    Check if systemd-resolved is using port 53"
+    echo "  --apply    Disable systemd-resolved DNSStubListener and restart"
+    echo "  --restore  Restore systemd-resolved to default configuration"
+    echo "  -h, --help Show this help message"
+    echo ""
+    echo "Without options, performs --check by default."
+}
+
+check_port_53() {
+    echo "Checking for port 53 listeners..."
+    
+    if command -v ss &>/dev/null; then
+        ss -tlnp | grep -q ":