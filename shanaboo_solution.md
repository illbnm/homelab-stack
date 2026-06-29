 ```diff
--- /dev/null
+++ b/stacks/network/docker-compose.yml
@@ -0,0 +1,120 @@
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
+      - "80:80/tcp"       # Admin web UI (after setup)
+    volumes:
+      - adguard-work:/opt/adguardhome/work
+      - adguard-conf:/opt/adguardhome/conf
+    environment:
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
+      - base
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.adguard.rule=Host(`adguard.${DOMAIN:-localhost}`)"
+      - "traefik.http.routers.adguard.entrypoints=websecure"
+      - "traefik.http.routers.adguard.tls.certresolver=letsencrypt"
+      - "traefik.http.services.adguard.loadbalancer.server.port=80"
+      - "traefik.http.routers.adguard.middlewares=authentik@docker"
+    healthcheck:
+      test: ["CMD", "wget", "-qO-", "http://localhost:80"]
+      interval: 30s
+      timeout: 10s
+      retries: 3
+
+  # Unbound - Recursive DNS resolver
+  unbound:
+    image: mvance/unbound:1.21.1
+    container_name: unbound
+    restart: unless-stopped
+    volumes:
+      - ./config/unbound:/opt/unbound/etc/unbound/custom.conf.d:ro
+    environment:
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
+    ports:
+      - "5053:53/tcp"
+      - "5053:53/udp"
+    healthcheck:
+      test: ["CMD", "dig", "@127.0.0.1", "-p", "53", "cloudflare.com"]
+      interval: 30s
+      timeout: 10s
+      retries: 3
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
+      - wireguard-data:/etc/wireguard
+    environment:
+      - WG_HOST=${WG_HOST:-vpn.example.com}
+      - PASSWORD_HASH=${WG_PASSWORD_HASH:-}
+      - WG_DEFAULT_DNS=adguard-home  # Point to AdGuard Home
+      - WG_DEFAULT_ADDRESS=10.8.0.x
+      - WG_ALLOWED_IPS=0.0.0.0/0,::/0
+      - WG_PERSISTENT_KEEPALIVE=25
+      - WG_MTU=1420
+      - UI_CHART_TYPE=2
+      - WG_ENABLE_EXPIRES_TIME=false
+    networks:
+      - network
+      - base
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.wg-easy.rule=Host(`vpn.${DOMAIN:-localhost}`)"
+      - "traefik.http.routers.wg-easy.entrypoints=websecure"
+      - "traefik.http.routers.wg-easy.tls.certresolver=letsencrypt"
+      - "traefik.http.services.wg-easy.loadbalancer.server.port=51821"
+      - "traefik.http.routers.wg-easy.middlewares=authentik@docker"
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
+      - CF_API_TOKEN=${CF_API_TOKEN}
+      - DOMAINS=${CF_DOMAINS}
+      - PROXIED=${CF_PROXIED:-false}
+      - IP4_PROVIDER=${CF_IP4_PROVIDER:-local}
+      - IP6_PROVIDER=${CF_IP6_PROVIDER:-local}
+      - UPDATE_CRON=@every 5m
+      - DELETE_ON_STOP=${CF_DELETE_ON_STOP:-false}
+      - TTL=${CF_TTL:-1}
+
+volumes:
+  adguard-work:
+  adguard-conf:
+  wireguard-data:
+
+networks:
+  network:
+    name: network
+  base:
+    external: true
--- /dev/null
+++ b/stacks/network/.env.example
@@ -0,0 +1,25 @@
+# Network Stack Environment Variables
+
+# General
+DOMAIN=example.com
+TZ=UTC
+
+# WireGuard Easy
+WG_HOST=vpn.example.com
+# Generate with: docker run ghcr.io/wg-easy/wg-easy:14 wgpw 'YOUR_PASSWORD'
+WG_PASSWORD_HASH=$$2a$$12$$...
+WG_DEFAULT_DNS=adguard-home
+
+# Cloudflare DDNS
+# Create token at: https://dash.cloudflare.com/profile/api-tokens
+# Required permissions: Zone:Read, DNS:Edit
+CF_API_TOKEN=your-cloudflare-api-token
+# Comma-separated list of domains/subdomains
+CF_DOMAINS=example.com,*.example.com,vpn.example.com
+# Whether to proxy through Cloudflare (orange cloud)
+CF_PROXIED=false
+# IP providers: local, cloudflare, opendns, etc.
+CF_IP4_PROVIDER=local
+CF_IP6_PROVIDER=local
+# Delete DNS records on container stop
+CF_DELETE_ON_STOP=false
+CF_TTL=1
--- /dev/null
+++ b/stacks/network/README.md
@@ -0,0 +1,189 @@
+# 🌐 Network Stack
+
+DNS filtering, VPN access,