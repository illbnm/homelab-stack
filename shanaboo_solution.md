 ```diff
--- /dev/null
+++ b/stacks/network/docker-compose.yml
@@ -0,0 +1,120 @@
+version: "3.8"
+
+networks:
+  network:
+    driver: bridge
+  traefik:
+    external: true
+
+volumes:
+  adguard-work:
+  adguard-conf:
+  unbound-conf:
+  wireguard-data:
+  npm-data:
+  npm-letsencrypt:
+
+services:
+  # =========================================
+  # AdGuard Home — DNS 过滤 + 广告屏蔽
+  # =========================================
+  adguard-home:
+    image: adguard/adguardhome:v0.107.52
+    container_name: adguard-home
+    restart: unless-stopped
+    networks:
+      - network
+    ports:
+      - "53:53/tcp"
+      - "53:53/udp"
+      - "3000:3000/tcp"   # 初始设置页面
+    volumes:
+      - adguard-work:/opt/adguardhome/work
+      - adguard-conf:/opt/adguardhome/conf
+    environment:
+      - TZ=${TZ:-UTC}
+    # 注意：首次启动后访问 http://<host>:3000 完成初始化
+    # 初始化完成后，可将 3000 端口移除或限制访问
+
+  # =========================================
+  # Unbound — 递归 DNS 解析器
+  # =========================================
+  unbound:
+    image: mvance/unbound:1.21.1
+    container_name: unbound
+    restart: unless-stopped
+    networks:
+      - network
+    volumes:
+      - unbound-conf:/opt/unbound/etc/unbound
+    environment:
+      - TZ=${TZ:-UTC}
+    # 可选：自定义 unbound 配置
+    # command: ["-c", "/opt/unbound/etc/unbound/unbound.conf"]
+
+  # =========================================
+  # WireGuard Easy — VPN 服务端
+  # =========================================
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
+      - "51821:51821/tcp"   # Web UI
+    volumes:
+      - wireguard-data:/etc/wireguard
+    environment:
+      - WG_HOST=${WG_HOST:-vpn.example.com}
+      - PASSWORD_HASH=${WG_PASSWORD_HASH:-}
+      - WG_DEFAULT_DNS=adguard-home  # 指向 AdGuard Home
+      - WG_ALLOWED_IPS=0.0.0.0/0,::/0
+      - WG_PERSISTENT_KEEPALIVE=25
+      - WG_DEFAULT_ADDRESS=10.8.0.x
+      - WG_MTU=1420
+      - UI_TRAFFIC_STATS=true
+      - UI_CHART_TYPE=2
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
+
+  # =========================================
+  # Cloud Cloudflare DDNS — 动态 DNS
+  # =========================================
+  cloudflare-ddns:
+    image: ghcr.io/favonia/cloudflare-ddns:1.14.0
+    container_name: cloudflare-ddns
+    restart: unless-stopped
+    network_mode: host
+    environment:
+      - CF_API_TOKEN=${CF_API_TOKEN:-}
+      - DOMAINS=${CF_DOMAINS:-}
+      - PROXIED=${CF_PROXIED:-false}
+      - TZ=${TZ:-UTC}
+      # IPv4 + IPv6 双栈支持
+      - IP4_PROVIDER=local
+      - IP6_PROVIDER=local
+      # 多域名通过逗号分隔配置在 DOMAINS 中
+      # 例如: DOMAINS=home.example.com,*.home.example.com
+
+  # =========================================
+  # Nginx Proxy Manager — 反向代理管理
+  # =========================================
+  nginx-proxy-manager:
+    image: jc21/nginx-proxy-manager:latest
+    container_name: nginx-proxy-manager
+    restart: unless-stopped
+    ports:
+      - "80:80"
+      - "81:81"      # Web UI (admin@example.com / changeme)
+      - "443:443"
+    volumes:
+      - npm-data:/data
+      - npm-letsencrypt:/etc/letsencrypt
+    environment:
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
+      - traefik
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.npm.rule=Host(`npm.${DOMAIN:-localhost}`)"
+      - "traefik.http.routers.npm.entrypoints=websecure"
+      - "traefik.http.routers.npm.tls.certresolver=letsencrypt"
+      - "traefik.http.services.npm.loadbalancer.server.port=81"
+      # 可选：通过 Traefik 暴露，或直接使用 81 端口
--- /dev/null
+++ b/stacks/network/.env.example
@@ -0,0 +1,28 @@
+# =========================================
+# Network Stack 环境变量
+# =========================================
+
+# 时区
+TZ=Asia/Shanghai
+
+# 基础域名 (用于 Traefik 路由)
+DOMAIN=example.com
+
+# =========================================
+# WireGuard Easy
+# =========================================
+
+# VPN 服务端域名或公网 IP
+WG_HOST=vpn.example.com
+
+# Web UI 密码 (bcrypt hash，可通过 https://bcrypt.online/ 生成)
+# 示例: changeme 的 hash
+WG_PASSWORD_HASH=$2a$12$K0ByB.6YI2/OZrplgMUCO.qpDWJ2i8XyXqZJ3QqQqQqQqQqQq