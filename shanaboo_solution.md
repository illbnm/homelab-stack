 ```diff
--- /dev/null
+++ b/stacks/base/docker-compose.yml
@@ -0,0 +1,120 @@
+services:
+  traefik:
+    image: traefik:v3.1.6
+    container_name: traefik
+    restart: unless-stopped
+    security_opt:
+      - no-new-privileges:true
+    networks:
+      - proxy
+    ports:
+      - "80:80"
+      - "443:443"
+    environment:
+      - TZ=${TZ:-Asia/Shanghai}
+    volumes:
+      - /var/run/docker.sock:/var/run/docker.sock:ro
+      - ./config/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
+      - ./config/traefik/dynamic:/etc/traefik/dynamic:ro
+      - traefik-acme:/etc/traefik/acme
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.traefik.rule=Host(`traefik.${DOMAIN}`)"
+      - "traefik.http.routers.traefik.entrypoints=websecure"
+      - "traefik.http.routers.traefik.tls.certresolver=letsencrypt"
+      - "traefik.http.routers.traefik.service=api@internal"
+      - "traefik.http.routers.traefik.middlewares=traefik-auth"
+      - "traefik.http.middlewares.traefik-auth.basicauth.users=${TRAEFIK_AUTH}"
+    healthcheck:
+      test: ["CMD", "traefik", "healthcheck"]
+      interval: 10s
+      timeout: 5s
+      retries: 3
+      start_period: 10s
+
+  socket-proxy:
+    image: tecnativa/docker-socket-proxy:0.2.0
+    container_name: socket-proxy
+    restart: unless-stopped
+    security_opt:
+      - no-new-privileges:true
+    networks:
+      - proxy
+    volumes:
+      - /var/run/docker.sock:/var/run/docker.sock:ro
+    environment:
+      - CONTAINERS=1
+      - SERVICES=1
+      - TASKS=1
+      - NETWORKS=1
+      - NODES=1
+      - INFO=1
+      - VERSION=1
+      - SYSTEM=0
+      - VOLUMES=0
+      - BUILD=0
+      - IMAGES=0
+      - POST=0
+      - TZ=${TZ:-Asia/Shanghai}
+    healthcheck:
+      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:2375/version"]
+      interval: 10s
+      timeout: 5s
+      retries: 3
+      start_period: 10s
+
+  portainer:
+    image: portainer/portainer-ce:2.21.3
+    container_name: portainer
+    restart: unless-stopped
+    security_opt:
+      - no-new-privileges:true
+    networks:
+      - proxy
+    volumes:
+      - /var/run/docker.sock:/var/run/docker.sock:ro
+      - portainer-data:/data
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.portainer.rule=Host(`portainer.${DOMAIN}`)"
+      - "traefik.http.routers.portainer.entrypoints=websecure"
+      - "traefik.http.routers.portainer.tls.certresolver=letsencrypt"
+      - "traefik.http.services.portainer.loadbalancer.server.port=9000"
+    healthcheck:
+      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9000/api/status"]
+      interval: 10s
+      timeout: 5s
+      retries: 3
+      start_period: 30s
+
+  watchtower:
+    image: containrrr/watchtower:1.7.1
+    container_name: watchtower
+    restart: unless-stopped
+    security_opt:
+      - no-new-privileges:true
+    networks:
+      - proxy
+    volumes:
+      - /var/run/docker.sock:/var/run/docker.sock:ro
+    environment:
+      - TZ=${TZ:-Asia/Shanghai}
+      - WATCHTOWER_SCHEDULE=0 0 3 * * *
+      - WATCHTOWER_LABEL_ENABLE=true
+      - WATCHTOWER_CLEANUP=true
+      - WATCHTOWER_INCLUDE_STOPPED=true
+      - WATCHTOWER_NOTIFICATIONS=gotify
+      - WATCHTOWER_NOTIFICATION_GOTIFY_URL=http://gotify:80
+      - WATCHTOWER_NOTIFICATION_GOTIFY_TOKEN=${WATCHTOWER_GOTIFY_TOKEN:-}
+
+networks:
+  proxy:
+    external: true
+
+volumes:
+  traefik-acme:
+  portainer-data:
--- /dev/null
+++ b/stacks/base/.env.example
@@ -0,0 +1,10 @@
+# Base Infrastructure Configuration
+DOMAIN=example.com
+ACME_EMAIL=admin@example.com
+
+# Traefik Dashboard Basic Auth (htpasswd format: user:password)
+# Generate with: htpasswd -nb admin yourpassword | openssl base64
+TRAEFIK_AUTH=admin:$apr1$H6uskkk1$IgXLPQew18e0Nih/qXlGb.
+
+# Timezone
+TZ=Asia/Shanghai
+
+# Watchtower Gotify Token (optional, for notifications)
+WATCHTOWER_GOTIFY_TOKEN=
--- /dev/null
+++ b/stacks/base/README.md
@@ -0,0 +1,95 @@
+# Base Infrastructure Stack
+
+This stack provides the core infrastructure for the entire HomeLab platform, including reverse proxy, container management UI, and automatic container updates.
+
+## Services
+
+| Service | Image | Purpose |
+|---------|-------|---------|
+| Traefik | `traefik:v3.1.6` | Reverse proxy + automatic HTTPS |
+| Portainer CE | `portainer/portainer-ce:2.21.3` | Docker management UI |
+| Watchtower | `containrrr/watchtower:1.7.1` | Automatic container updates |
+| Socket Proxy | `tecnativa/docker-socket-proxy:0.2.0` | Secure Docker socket isolation |
+
+## Prerequisites
+
+- Docker Engine >= 20.10
+- Docker Compose >= 2.0
+- A domain name with DNS A/AAAA records pointing to your server
+- Ports 80 and 443 open and accessible from the internet
+
+## DNS Configuration