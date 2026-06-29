 ```diff
--- /dev/null
+++ b/stacks/network/docker-compose.yml
@@ -0,0 +1,120 @@
+version: "3.8"
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
+      - "80:80/tcp"       # Web UI after setup (or use 8080)
+    volumes:
+      - ./adguard/work:/opt/adguardhome/work
+      - ./adguard/conf:/opt/adguardhome/conf
+    environment:
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
+    dns:
+      - 127.0.0.1
+      - 1.1.1.1
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.adguard.rule=Host(`adguard.${DOMAIN:-localhost}`)"
+      - "traefik.http.routers.adguard.entrypoints=websecure"
+      - "traefik.http.routers.adguard.tls.certresolver=letsencrypt"
+      - "traefik.http.services.adguard.loadbalancer.server.port=80"
+
+  # Unbound - Recursive DNS resolver
+  unbound:
+    image: mvance/unbound:1.21.1
+    container_name: unbound
+    restart: unless-stopped
+    volumes:
+      - ./unbound/unbound.conf:/opt/unbound/etc/unbound/unbound.conf:ro
+      - ./unbound/conf.d:/opt/unbound/etc/unbound/conf.d:ro
+    networks:
+      - network
+    ports:
+      - "5053:53/tcp"
+      - "5053:53/udp"
+    labels:
+      - "traefik.enable=false"
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
+      - ./wireguard:/etc/wireguard
+    environment:
+      - WG_HOST=${WG_HOST:-vpn.example.com}
+      - PASSWORD_HASH=${WG_PASSWORD_HASH:-}
+      - WG_DEFAULT_DNS=adguard-home  # Point to AdGuard Home
+      - WG_ALLOWED_IPS=0.0.0.0/0,::/0
+      - WG_PERSISTENT_KEEPALIVE=25
+      - WG_DEFAULT_ADDRESS=10.8.0.x
+      - WG_PORT=51820
+      - WG_MTU=1420
+      - UI_TRAFFIC_STATS=true
+      - UI_CHART_TYPE=2
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.wg-easy.rule=Host(`vpn.${DOMAIN:-localhost}`)"
+      - "traefik.http.routers.wg-easy.entrypoints=websecure"
+      - "traefik.http.routers.wg-easy.tls.certresolver=letsencrypt"
+      - "traefik.http.services.wg-easy.loadbalancer.server.port=51821"
+
+  # Cloudflare DDNS - Dynamic DNS updater
+  cloudflare-ddns:
+    image: ghcr.io/favonia/cloudflare-ddns:1.14.0
+    container_name: cloudflare-ddns
+    restart: unless-stopped
+    network_mode: host
+    volumes:
+      - /etc/localtime:/etc/localtime:ro
+    environment:
+      - CF_API_TOKEN=${CF_API_TOKEN:-}
+      - CF_ZONE_NAME=${CF_ZONE_NAME:-}
+      - DOMAINS=${CF_DOMAINS:-}
+      - PROXIED=${CF_PROXIED:-false}
+      - TZ=${TZ:-UTC}
+      - IP4_PROVIDER=local
+      - IP6_PROVIDER=local
+      - UPDATE_CRON=@every 5m
+      - DELETE_ON_STOP=false
+      - TTL=1
+    labels:
+      - "traefik.enable=false"
+
+networks:
+  network:
+    name: network
+    driver: bridge
+    external: false
--- /dev/null
+++ b/stacks/network/.env.example
@@ -0,0 +1,23 @@
+# Network Stack Environment Variables
+
+# General
+TZ=Asia/Shanghai
+DOMAIN=example.com
+
+# WireGuard
+WG_HOST=vpn.example.com
+# Generate with: docker run -it ghcr.io/wg-easy/wg-easy:14 wgpw 'your_password'
+WG_PASSWORD_HASH=$$2a$$12$$...
+
+# Cloudflare DDNS
+# Create token at: https://dash.cloudflare.com/profile/api-tokens
+# Required permissions: Zone:Read, DNS:Edit
+CF_API_TOKEN=your_cloudflare_api_token
+CF_ZONE_NAME=example.com
+# Comma-separated list of domains to update
+CF_DOMAINS=vpn.example.com,ddns.example.com
+# Whether to proxy through Cloudflare (orange cloud)
+CF_PROXIED=false
+
+# AdGuard Home initial setup
+# After first start, access http://your-server:3000 to complete setup
+# Set upstream DNS to: unbound:53 or 127.0.0.1#5053
--- /dev/null
+++ b/stacks network/scripts/fix-dns-port.sh
@@ -0,0 +1,111 @@
+#!/usr/bin/env bash
+#
+# fix-dns-port.sh
+# Detect and disable systemd-resolved's port 53 binding to free it for AdGuard Home
+#
+# Usage: ./fix-dns-port.sh [--check|--apply|--restore]
+#
+
+set -euo pipefail
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+BACKUP_DIR="${SCRIPT_DIR}/../backups"
+BACKUP_FILE="${BACKUP_DIR}/resolved.conf.backup"
+
+# Colors for output