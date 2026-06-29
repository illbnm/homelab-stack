 ```diff
--- /dev/null
+++ b/stacks/network/docker-compose.yml
@@ -0,0 +1,126 @@
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
+      - ./adguard-home/work:/opt/adguardhome/work
+      - ./adguard-home/conf:/opt/adguardhome/conf
+    environment:
+      - TZ=${TZ:-UTC}
+    networks:
+      - network-stack
+      - traefik-network
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.adguard.rule=Host(`adguard.${DOMAIN:-localhost}`)"
+      - "traefik.http.routers.adguard.entrypoints=websecure"
+      - "traefik.http.routers.adguard.tls.certresolver=letsencrypt"
+      - "traefik.http.services.adguard.loadbalancer.server.port=80"
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
+    ports:
+      - "5053:53/tcp"
+      - "5053:53/udp"
+    volumes:
+      - ./unbound/conf:/opt/unbound/etc/unbound
+    environment:
+      - TZ=${TZ:-UTC}
+    networks:
+      - network-stack
+
+  # WireGuard Easy - VPN server with Web UI
+  wg-easy:
+    image: ghcr.io/wg-easy/wg-easy:14
+    container_name: wg-easy
+    restart: unless-stopped
+    cap_add:
+      - NET_ADMIN
+      - SYS_MODULE
+    ports:
+      - "51820:51820/udp"
+      - "51821:51821/tcp"  # Web UI
+    volumes:
+      - ./wireguard:/etc/wireguard
+    environment:
+      - WG_HOST=${WG_HOST:-vpn.example.com}
+      - PASSWORD_HASH=${WG_PASSWORD_HASH:-}
+      - WG_DEFAULT_DNS=adguard-home  # Point to AdGuard Home
+      - WG_ALLOWED_IPS=0.0.0.0/0,::/0  # Full tunnel (change for split tunnel)
+      - WG_PERSISTENT_KEEPALIVE=25
+      - WG_DEFAULT_ADDRESS=10.8.0.x
+      - WG_MTU=1420
+      - UI_TRAFFIC_STATS=true
+      - UI_CHART_TYPE=2
+      - TZ=${TZ:-UTC}
+    sysctls:
+      - net.ipv4.conf.all.src_ip_ct=1
+      - net.ipv4.ip_forward=1
+    networks:
+      - network-stack
+      - traefik-network
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.wg-easy.rule=Host(`wg.${DOMAIN:-localhost}`)"
+      - "traefik.http.routers.wg-easy.entrypoints=websecure"
+      - "traefik.http.routers.wg-easy.tls.certresolver=letsencrypt"
+      - "traefik.http.services.wg-easy.loadbalancer.server.port=51821"
+
+  # Cloudflare DDNS - Dynamic DNS updater
+  cloudflare-ddns:
+    image: ghcr.io/favonia/cloudflare-ddns:1.14.0
+    container_name: cloudflare-ddns
+    restart: unless-stopped
+    environment:
+      - CF_API_TOKEN=${CF_API_TOKEN:-}
+      - CF_ZONE_ID=${CF_ZONE_ID:-}
+      - DOMAINS=${CF_DOMAINS:-example.com}
+      - PROXIED=${CF_PROXIED:-false consecrate}
+      - TZ=${TZ:-UTC}
+      - IP4_PROVIDER=cloudflare.trace
+      - IP6_PROVIDER=cloudflare.trace
+      - UPDATE_CRON=@every 5m
+      - UPDATE_ON_START=true
+      - DELETE_ON_STOP=true
+      - CACHE_EXPIRATION=6h0m
+    networks:
+      - network-stack
+
+  # Nginx Proxy Manager - Reverse proxy management
+  nginx-proxy-manager:
+    image: jc21/nginx-proxy-manager:latest
+    container_name: nginx-proxy-manager
+    restart: unless-stopped
+    ports:
+      - "80:80"
+      - "81:81"   # Admin UI
+      - "443:443"
+    volumes:
+      - ./nginx-proxy-manager/data:/data
+      - ./nginx-proxy-manager/letsencrypt:/etc/letsencrypt
+    environment:
+      - TZ=${TZ:-UTC}
+    networks:
+      - network-stack
+      - traefik-network
+
+networks:
+  network-stack:
+    driver: bridge
+  traefik-network:
+    external: true
+
--- /dev/null
+++ b/stacks/network/.env.example
@@ -0,0 +1,23 @@
+# Network Stack Environment Variables
+
+# Domain for services
+DOMAIN=example.com
+
+# Timezone
+TZ=Asia/Shanghai
+
+# WireGuard Settings
+WG_HOST=vpn.example.com
+WG_PASSWORD_HASH=$2y$10$...  # bcrypt hash of admin password
+
+# Cloudflare DDNS Settings
+CF_API_TOKEN=your_cloudflare_api_token
+CF_ZONE_ID=your_cloudflare_zone_id
+CF_DOMAINS=home.example.com,vpn.example.com,*.home.example.com
+CF_PROXIED=false
+
+# Nginx Proxy Manager Settings
+# Default login: admin@example.com / changeme
+# Change immediately after first login!
+
+# AdGuard Home initial setup password (configure via web UI)
+# Access at http://your-server:3000
--- /dev/null
+++ b/stacks/network/README.md
@@ -0,0 +1,189 @@
+# Network Stack
+
+家庭网络基础设施栈，包含 DNS 过滤、VPN 接入