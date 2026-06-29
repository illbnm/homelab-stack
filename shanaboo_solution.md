 ```diff
--- /dev/null
+++ b/stacks/network/docker-compose.yml
@@ -0,0 +1,96 @@
+version: "3.8"
+
+networks:
+  network:
+    driver: bridge
+  traefik:
+    external: true
+
+volumes:
+  adguard-data:
+  adguard-conf:
+  wireguard-data:
+  unbound-data:
+
+services:
+  adguard:
+    image: adguard/adguardhome:v0.107.52
+    container_name: adguard
+    restart: unless-stopped
+    ports:
+      - "53:53/udp"
+      - "53:53/tcp"
+      - "3000:3000/tcp"
+    volumes:
+      - adguard-data:/opt/adguardhome/work
+      - adguard-conf:/opt/adguardhome/conf
+      - ./config/adguard/AdGuardHome.yaml:/opt/adguardhome/conf/AdGuardHome.yaml:ro
+    environment:
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
+      - traefik
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.adguard.rule=Host(`adguard.${DOMAIN:-localhost}`)"
+      - "traefik.http.routers.adguard.entrypoints=websecure"
+      - "traefik.http.routers.adguard.tls.certresolver=letsencrypt"
+      - "traefik.http.services.adguard.loadbalancer.server.port=3000"
+
+  unbound:
+    image: mvance/unbound:1.21.1
+    container_name: unbound
+    restart: unless-stopped
+    volumes:
+      - unbound-data:/opt/unbound/etc/unbound
+      - ./config/unbound/unbound.conf:/opt/unbound/etc/unbound/unbound.conf:ro
+    networks:
+      - network
+    environment:
+      - TZ=${TZ:-UTC}
+
+  wireguard:
+    image: ghcr.io/wg-easy/wg-easy:14
+    container_name: wireguard
+    restart: unless-stopped
+    cap_add:
+      - NETato
+      - SYS_MODULE
+    sysctls:
+      - net.ipv4.conf.all.src_valid_mark=1
+      - net.ipv4.ip_forward=1
+    ports:
+      - "51820:51820/udp"
+      - "51821:51821/tcp"
+    volumes:
+      - wireguard-data:/etc/wireguard
+    environment:
+      - WG_HOST=${WG_HOST:-vpn.example.com}
+      - PASSWORD_HASH=${WG_PASSWORD_HASH:-}
+      - WG_DEFAULT_DNS=adguard
+      - WG_ALLOWED_IPS=0.0.0.0/0,::/0
+      - WG_PERSISTENT_KEEPALIVE=25
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
+      - traefik
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.wireguard.rule=Host(`wireguard.${DOMAIN:-localhost}`)"
+      - "traefik.http.routers.wireguard.entrypoints=websecure"
+      - "traefik.http.routers.wireguard.tls.certresolver=letsencrypt"
+      - "traefik.http.services.wireguard.loadbalancer.server.port=51821"
+
+  cloudflare-ddns:
+    image: ghcr.io/favonia/cloudflare-ddns:1.14.0
+    container_name: cloudflare-ddns
+    restart: unless-stopped
+    environment:
+      - CF_API_TOKEN=${CF_API_TOKEN:-}
+      - DOMAINS=${CF_DOMAINS:-}
+      - PROXIED=false
+      - TZ=${TZ:-UTC}
+    networks:
+      - network
--- /dev/null
+++ b/stacks/network/.env.example
@@ -0,0 +1,15 @@
+# Network Stack Environment Variables
+
+# AdGuard Home
+DOMAIN=example.com
+
+# WireGuard Easy
+WG_HOST=vpn.example.com
+WG_PASSWORD_HASH=$$2y$$10$$... # bcrypt hash of your password
+
+# Cloudflare DDNS
+CF_API_TOKEN=your_cloudflare_api_token
+CF_DOMAINS=home.example.com,vpn.example.com
+
+# Global
+TZ=Asia/Shanghai
--- /dev/null
+++ b/stacks/network/config/adguard/AdGuardHome.yaml
@@ -0,0 +1,95 @@
+bind_host: 0.0.0.0
+bind_port: 3000
+users:
+  - name: admin
+    password: $2a$10$... # bcrypt hash
+http:
+  pprof:
+    port: 6060
+    enabled: false
+  session:
+    ttl: 720h
+dns:
+  bind_hosts:
+    - 0.0.0.0
+  port: 53
+  anonymize_client_ip: false
+  ratelimit: 20
+  ratelimit_subnet_len_ipv4: 24
+  ratelimit_subnet_len_ipv6: 56
+  ratelimit_whitelist: []
+  refuse_any: true
+  upstream_dns:
+    - unbound:53
+  upstream_dns_file: ""
+  bootstrap_dns:
+    - 1.1.1.1:53
+    - 8.8.8.8:53
+  fallback_dns: []
+  all_servers: false
+  fastest_addr: false
+  fastest_timeout: 1s
+  allowed_clients: []
+  disallowed_clients: []
+  blocked_hosts:
+    - version.bind
+    - id.server
+    - hostname.bind
+  trusted_proxies:
+    - 127.0.0.0/8
+    - ::1/128
+  cache_size: 4194304
+  cache_ttl_min: 0
+  cache_ttl_max: 0
+  cache_optimistic: false
+  bogus_nxdomain: []
+  aaaa_disabled: false
+  enable_dnssec: true
+  edns_client_subnet:
+    enabled: false
+    use_custom: false
+    custom_ip: ""
+  max_goroutines: 300
+  handle_ddr: true
+  ipset: []
+  ipset_file: ""
+  filtering:
+    ipv6_disabled: false
+    rdns:
+      enabled: true
+      max_requests: 5
+      ttl: 10
+      cache_size: 1000
+      cache_ttl_min: 600