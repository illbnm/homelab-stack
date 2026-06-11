 ```diff
--- /dev/null
+++ b/stacks/base/docker-compose.yml
@@ -0,0 +1,118 @@
+---
+# Base Infrastructure Stack
+# Services: Traefik, Portainer, Watchtower, Docker Socket Proxy
+
+services:
+  # ------------------------------------------------------------------
+  # Docker Socket Proxy — secure Docker socket access
+  # ------------------------------------------------------------------
+  socket-proxy:
+    image: tecnativa/docker-socket-proxy:0.2.0
+    container_name: socket-proxy
+    restart: unless-stopped
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
+      - POST=0
+      - BUILD=0
+      - COMMIT=0
+      - CONFIGS=0
+      - DISTRIBUTION=0
+      - EXEC=0
+      - IMAGES=0
+      - PLUGINS=0
+      - SECRETS=0
+      - SESSION=0
+      - SWARM=0
+      - SYSTEM=0
+      - VOLUMES=0
+    healthcheck:
+      test: ["CMD", "wget", "--spider", "-q", "http://localhost:2375/version"]
+      interval: 10s
+      timeout: 5s
+      retries: 3
+      start_period: 10s
+
+  # ------------------------------------------------------------------
+  # Traefik — reverse proxy + auto HTTPS
+  # ------------------------------------------------------------------
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
+    volumes:
+      - ../../config/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
+      - ../../config/traefik/dynamic:/etc/traefik/dynamic:ro
+      - traefik-acme:/etc/traefik/acme
+    environment:
+      - DOMAIN=${DOMAIN}
+      - ACME_EMAIL=${ACME_EMAIL}
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.traefik.rule=Host(`traefik.${DOMAIN}`)"
+      - "traefik.http.routers.traefik.entrypoints=websecure"
+      - "traefik.http.routers.traefik.tls.certresolver=letsencrypt"
+      - "traefik.http.routers.traefik.service=api@internal"
+      - "traefik.http.routers.traefik.middlewares=traefik-auth"
+      - "traefik.http.middlewares.traefik-auth.basicauth.users=${TRAEFIK_AUTH}"
+    healthcheck:
+      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/ping"]
+      interval: 10s
+      timeout: 5s
+      retries: 3
+      start_period: 10s
+
+  # ------------------------------------------------------------------
+  # Portainer CE — Docker management UI
+  # ------------------------------------------------------------------
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
+      - "traefik.http.routers.portainer.service=portainer"
+      - "traefik.http.services.portainer.loadbalancer.server.port=9000"
+    healthcheck:
+      test: ["CMD", "wget", "--spider", "-q", "http://localhost:9000/api/status"]
+      interval: 10s
+      timeout: 5s
+      retries: 3
+      start_period: 30s
+
+  # ------------------------------------------------------------------
+  # Watchtower — automatic container updates
+  # ------------------------------------------------------------------
+  watchtower:
+    image: containrrr/watchtower:1.7.1
+    container_name: watchtower
+    restart: unless-stopped
+    networks:
+      - proxy
+    volumes:
+      - /var/run/docker.sock:/var/run/docker.sock:ro
+    environment:
+      - TZ=${TZ:-Asia/Shanghai}
+      - WATCHTOWER_CLEANUP=true
+      - WATCHTOWER_INCLUDE_STOPPED=true
++      - WATCHTOWER_POLL_INTERVAL=0
+      - WATCHTOWER_SCHEDULE=0 0 3 * * *
+      - WATCHTOWER_LABEL_ENABLE=true
+      - WATCHTOWER_NOTIFICATIONS_LEVEL=info
+      - WATCHTOWER_NOTIFICATION_URL=${WATCHTOWER_NOTIFICATION_URL:-}
+    labels:
+      - "com.centurylinklabs.watchtower.enable=true"
+    healthcheck:
+      test: ["CMD", "sh", "-c", "ps aux | grep -q '[w]atchtower'"]
+      interval: 30s
+      timeout: 5s
+      retries: 3
+      start_period: 10s
+
+networks:
+  proxy:
+    external: true
+
+volumes:
+  traefik-acme:
+  portainer-data:
+
+--- /dev/null
+++ b/stacks/base/.env.example
@@ -0,0 +1,20 @@
+# Base Infrastructure Stack Environment Variables
+
+# Domain for all services
+DOMAIN=example.com
+
+# Let's Encrypt ACME email address
+ACME_EMAIL=admin@example.com
+
+# Traefik Dashboard Basic Auth
+# Generate with: htpasswd -nb admin yourpassword | openssl base64
+# Or: htpasswd -nb admin yourpassword
+# Example: admin:$apr1$H6uskkk7$IgXQTQ2e8h3qZzX3e4v5f1
+TRAEFIK_AUTH=
+
+# Timezone
+TZ=Asia/Shanghai
+
