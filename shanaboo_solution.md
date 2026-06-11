 ```diff
--- /dev/null
+++ b/stacks/base/docker-compose.yml
@@ -0,0 +1,145 @@
+---
+# Base Infrastructure Stack
+# Services: Traefik, Portainer, Watchtower, Docker Socket Proxy
+
+services:
+  # ─────────────────────────────────────────────
+  # Docker Socket Proxy (security isolation)
+  # ─────────────────────────────────────────────
+  socket-proxy:
+    image: tecnativa/docker-socket-proxy:0.2.0
+    container_name: socket-proxy
+    restart: unless-stopped
+    security_opt:
+      - no-new-privileges:true
+    read_only: true
+    tmpfs:
+      - /run
+    environment:
+      - CONTAINERS=1
+      - INFO=1
+      - NETWORKS=1
+      - SERVICES=1
+      - TASKS=1
+      - NODES=1
+      - VERSION=1
+      - PING=1
+      - POST=0
+      - PUT=0
+      - DELETE=0
+    volumes:
+      - /var/run/docker.sock:/var/run/docker.sock:ro
+    networks:
+      - socket-proxy
+    healthcheck:
+      test: ["CMD", "wget", "--spider", "-q", "http://localhost:2375/version"]
+      interval: 10s
+      timeout: 5s
+      retries: 3
+
+  # ─────────────────────────────────────────────
+  # Traefik (reverse proxy + auto HTTPS)
+  # ─────────────────────────────────────────────
+  traefik:
+    image: traefik:v3.1.6
+    container_name: traefik
+    restart: unless-stopped
+    security_opt:
+      - no-new-privileges:true
+    command:
+      - --configFile=/etc/traefik/traefik.yml
+    ports:
+      - "80:80"
+      - "443:443"
+    environment:
+      - DOMAIN=${DOMAIN}
+      - ACME_EMAIL=${ACME_EMAIL}
+      - TRAEFIK_AUTH=${TRAEFIK_AUTH}
+    volumes:
+      - ../../config/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
+      - ../../config/traefik/dynamic:/etc/traefik/dynamic:ro
+      - ../../data/traefik/acme:/etc/traefik/acme
+    networks:
+      - proxy
+      - socket-proxy
+    depends_on:
+      socket-proxy:
+        condition: service_healthy
+    labels:
+      - traefik.enable=true
+      - traefik.http.routers.traefik.rule=Host(`traefik.${DOMAIN}`)
+      - traefik.http.routers.traefik.entrypoints=websecure
+      - traefik.http.routers.traefik.tls.certresolver=letsencrypt
+      - traefik.http.routers.traefik.service=api@internal
+      - traefik.http.routers.traefik.middlewares=traefik-auth
+      - traefik.http.middlewares.traefik-auth.basicauth.users=${TRAEFIK_AUTH}
+    healthcheck:
+      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/ping"]
+      interval: 10s
+      timeout: 5s
+      retries: 3
+
+  # ─────────────────────────────────────────────
+  # Portainer CE (Docker management UI)
+  # ─────────────────────────────────────────────
+  portainer:
+    image: portainer/portainer-ce:2.21.3
+    container_name: portainer
+    restart: unless-stopped
+    security_opt:
+      - no-new-privileges:true
+    command: -H tcp://socket-proxy:2375
+    volumes:
+      - ../../data/portainer:/data
+    networks:
+      - proxy
+      - socket-proxy
+    depends_on:
+      socket-proxy:
+        condition: service_healthy
+    labels:
+      - traefik.enable=true
+      - traefik.http.routers.portainer.rule=Host(`portainer.${DOMAIN}`)
+      - traefik.http.routers.portainer.entrypoints=websecure
+      - traefik.http.routers.portainer.tls.certresolver=letsencrypt
+      - traefik.http.routers.portainer.service=portainer
+      - traefik.http.services.portainer.loadbalancer.server.port=9000
+    healthcheck:
+      test: ["CMD", "wget", "--spider", "-q", "http://localhost:9000/api/status"]
+      interval: 10s
+      timeout: 5s
+      retries: 3
+
+  # ─────────────────────────────────────────────
+  # Watchtower (container auto-updates)
+  # ─────────────────────────────────────────────
+  watchtower:
+    image: containrrr/watchtower:1.7.1
+    container_name: watchtower
+    restart: unless-stopped
+    environment:
+      - TZ=${TZ}
+      - WATCHTOWER_SCHEDULE=0 0 3 * * *
+      - WATCHTOWER_LABEL_ENABLE=true
+      - WATCHTOWER_CLEANUP=true
+      - WATCHTOWER_INCLUDE_STOPPED=true
+      - WATCHTOWER_NOTIFICATIONS=gotify
+      - WATCHTOWER_NOTIFICATION_GOTIFY_URL=${GOTIFY_URL:-}
+      - WATCHTOWER_NOTIFICATION_GOTIFY_TOKEN=${GOTIFY_TOKEN:-}
+      - WATCHTOWER_NOTIFICATION_GOTIFY_TLS_SKIP_VERIFY=${GOTIFY_TLS_SKIP_VERIFY:-false}
+    volumes:
+      - /var/run/docker.sock:/var/run/docker.sock:ro
+    networks:
+      - socket-proxy
+    labels:
+      - com.centurylinklabs.watchtower.enable=true
+
+networks:
+  proxy:
+    external: true
+  socket-proxy:
+    name: socket-proxy
+    driver: bridge
+
--- /dev/null
+++ b/stacks/base/.env.example
@@ -0,0 +1,20 @@
+# ─────────────────────────────────────────────
+# Base Infrastructure Stack Environment
+# ─────────────────────────────────────────────
+
+# Domain configuration
+DOMAIN=example.com
+
+# Let's Encrypt ACME email
+ACME_EMAIL=admin@example.com
+
+# Traefik Dashboard Basic Auth (htpasswd format)
+# Generate with: htpasswd -nb admin yourpassword | openssl base64
+TRAEFIK_AUTH=
+
+# Timezone
+TZ=Asia/Shanghai
+
+# Notifications (optional - integrates with notifications stack)
+GOTIFY_URL=http://gotify:80
+GOTIFY_TOKEN=
+GOTIFY_TLS_SKIP_VERIFY=false
+
---