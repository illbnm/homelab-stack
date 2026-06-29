 ```diff
--- /dev/null
+++ b/stacks/network/docker-compose.yml
@@ -0,0 +1,120 @@
+version: "3.8"
+
+services:
+  # AdGuard Home - DNS 过滤 + 广告屏蔽
+  adguardhome:
+    image: adguard/adguardhome:v0.107.52
+    container_name: adguardhome
+    restart: unless-stopped
+    ports:
+      - "53:53/tcp"
+      - "53:53/udp"
+      - "3000:3000/tcp"  # 初始设置页面
+    volumes:
+      - ${DATA_DIR}/adguardhome/work:/opt/adguardhome/work
+      - ${DATA_DIR}/adguardhome/conf:/opt/adguardhome/conf
+    environment:
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
+      - proxy
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.adguardhome.rule=Host(`${ADGUARD_DOMAIN:-adguard.home.local}`)"
+      - "traefik.http.routers.adguardhome.entrypoints=websecure"
+      - "traefik.http.routers.adguardhome.tls.certresolver=letsencrypt"
+      - "traefik.http.services.adguardhome.loadbalancer.server.port=80"
+    healthcheck:
+      test: ["CMD", "wget", "-q", "--spider", "http://localhost:80"]
+      interval: 30s
+      timeout: 10s
+      retries: 3
+
+  # Unbound - 递归 DNS 解析器
+  unbound:
+    image: mvance/unbound:1.21.1
+    container_name: unbound
+    restart: unless-stopped
+    ports:
+      - "5335:53/tcp"
+      - "5335:53/udp"
+    volumes:
+      - ${DATA_DIR}/unbound:/opt/unbound/etc/unbound
+    environment:
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
+    healthcheck:
+      test: ["CMD", "dig", "@127.0.0.1", ".", "NS"]
+      interval: 30s
+      timeout: 10s
+      retries: 3
+
+  # WireGuard Easy - VPN 服务端
+  wg-easy:
+    image: ghcr.io/wg-easy/wg-easy:14
+    container_name: wg-easy
+    restart: unless-stopped
+    cap_add:
+      - NET_ADMIN
+      - SYS_MODULE
+    sysctls:
+      - net.ipv4.conf.all.src_ip_forward=1
+      - net.ipv4.ip_forward=1
+      - net.ipv6.conf.all.forwarding=1
+    ports:
+      - "51820:51820/udp"
+      - "51821:51821/tcp"  # Web UI
+    volumes:
+      - ${DATA_DIR}/wg-easy:/etc/wireguard
+    environment:
+      - WG_HOST=${WG_HOST:-vpn.example.com}
+      - PASSWORD_HASH=${WG_PASSWORD_HASH:-}
+      - WG_DEFAULT_DNS=${WG_DEFAULT_DNS:-10.8.1.1}
+      - WG_ALLOWED_IPS=${WG_ALLOWED_IPS:-0.0.0.0/0,::/0}
+      - WG_PERSISTENT_KEEPALIVE=${WG_PERSISTENT_KEEPALIVE:-25}
+      - WG_DEFAULT_ADDRESS=${WG_DEFAULT_ADDRESS:-10.8.1.x}
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.wg-easy.rule=Host(`${WG_DOMAIN:-wg.home.local}`)"
+      - "traefik.http.routers.wg-easy.entrypoints=websecure"
+      - "traefik.http.routers.wg-easy.tls.certresolver=letsencrypt"
+      - "traefik.http.services.wg-easy.loadbalancer.server.port=51821"
+
+  # Cloudflare DDNS - 动态 DNS
+  cloudflare-ddns:
+    image: ghcr.io/favonia/cloudflare-ddns:1.14.0
+    container_name: cloudflare-ddns
+    restart: unless-stopped
+    environment:
+      - CF_API_TOKEN=${CF_API_TOKEN}
+      - DOMAINS=${CF_DOMAINS}
+      - PROXIED=${CF_PROXIED:-false}
+      - IP6_PROVIDER=${CF_IP6_PROVIDER:-none}
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
+
+networks:
+  network:
+    name: network
+    driver: bridge
+  proxy:
+    external: true
+    name: proxy
+
+--- /dev/null
+++ b/stacks/network/.env.example
@@ -0,0 +1,32 @@
+# Network Stack Environment Variables
+
+# Data directory
+DATA_DIR=./data
+
+# Timezone
+TZ=Asia/Shanghai
+
+# AdGuard Home
+ADGUARD_DOMAIN=adguard.yourdomain.com
+
+# WireGuard
+WG_HOST=vpn.yourdomain.com
+WG_DOMAIN=wg.yourdomain.com
+WG_PASSWORD_HASH=$$2y$$10$$... # bcrypt hash of your password
+WG_DEFAULT_DNS=10.8.1.1
+WG_ALLOWED_IPS=0.0.0.0/0,::/0
+WG_PERSISTENT_KEEPALIVE=25
+WG_DEFAULT_ADDRESS=10.8.1.x
+
+# Cloudflare DDNS
+# Create token at: https://dash.cloudflare.com/profile/api-tokens
+# Required permissions: Zone:Read, DNS:Edit
+CF_API_TOKEN=your-cloudflare-api-token
+CF_DOMAINS=example.com,sub.example.com
+CF_PROXIED=false
+CF_IP6_PROVIDER=none
+
+# Nginx Proxy Manager (optional, if using instead of Traefik)
+NPM_DOMAIN=npm.yourdomain.com
+
+--- /dev/null
+++ b stacks/network/README.md
@@ -0,0 +1,200 @@
+# 🌐 Network Stack
+
+> DNS 过滤、VPN 接入、动态域名 — 家庭网络基础设施
+
+## 服务组成
+
+| 服务 | 镜像 | 用途 |
+|------|------|------|
+| AdGuard Home | `adguard/adguardhome:v0.107.52` | DNS 过滤 + 广告屏蔽 |
+| WireGuard Easy | `ghcr.io/wg-easy/wg-easy:14` | VPN 服务端 |
+| Cloudflare DDNS | `ghcr