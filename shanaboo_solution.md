 ```diff
--- /dev/null
+++ b/stacks/storage/docker-compose.yml
@@ -0,0 +1,264 @@
+version: "3.8"
+
+networks:
+  traefik:
+    external: true
+    name: traefik
+  storage:
+    driver: bridge
+
+volumes:
+  nextcloud-data:
+  nextcloud-apps:
+  nextcloud-config:
+  minio-data:
+  filebrowser-data:
+  syncthing-data:
+
+services:
+  # ==========================================
+  # Nextcloud FPM
+  # ==========================================
+  nextcloud:
+    image: nextcloud:29.0.7-fpm-alpine
+    container_name: nextcloud
+    restart: unless-stopped
+    environment:
+      - POSTGRES_HOST=${POSTGRES_HOST:-postgres}
+      - POSTGRES_DB=${NEXTCLOUD_DB:-nextcloud}
+      - POSTGRES_USER=${NEXTCLOUD_DB_USER:-nextcloud}
+      - POSTGRES_PASSWORD=${NEXTCLOUD_DB_PASSWORD}
+      - NEXTCLOUD_ADMIN_USER=${NEXTCLOUD_ADMIN_USER}
+      - NEXTCLOUD_ADMIN_PASSWORD=${NEXTCLOUD_ADMIN_PASSWORD}
+      - NEXTCLOUD_TRUSTED_DOMAINS=${NEXTCLOUD_DOMAIN}
+      - OVERWRITEPROTOCOL=https
+      - OVERWRITEHOST=${NEXTCLOUD_DOMAIN}
+      - OVERWRITEWEBROOT=
+      - OVERWRITECONDADDR=
+      - TRUSTED_PROXIES=172.0.0.0/8
+      - REDIS_HOST=${REDIS_HOST:-redis}
+      - REDIS_HOST_PORT=${REDIS_PORT:-6379}
+      - REDIS_HOST_PASSWORD=${REDIS_PASSWORD}
+    volumes:
+      - nextcloud-data:/var/www/html/data
+      - nextcloud-apps:/var/www/html/apps
+      - nextcloud-config:/var/www/html/config
+      - ./config/nextcloud/config.php:/var/www/html/config/config.php:ro
+    networks:
+      - traefik
+      - storage
+    depends_on:
+      - nextcloud-init
+    healthcheck:
+      test: ["CMD", "php", "-v"]
+      interval: 30s
+      timeout: 10s
+      retries: 3
+
+  # ==========================================
+  # Nextcloud Nginx Frontend
+  # ==========================================
+  nextcloud-nginx:
+    image: nginx:1.27-alpine
+    container_name: nextcloud-nginx
+    restart: unless-stopped
+    volumes:
+      - nextcloud-data:/var/www/html/data:ro
+      - nextcloud-apps:/var/www/html/apps:ro
+      - nextcloud-config:/var/www/html/config:ro
+      - ./config/nginx/nextcloud.conf:/etc/nginx/conf.d/default.conf:ro
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.nextcloud.rule=Host(`${NEXTCLOUD_DOMAIN}`)"
+      - "traefik.http.routers.nextcloud.entrypoints=websecure"
+      - "traefik.http.routers.nextcloud.tls.certresolver=letsencrypt"
+      - "traefik.http.routers.nextcloud.middlewares=nextcloud-redirect,nextcloud-headers"
+      - "traefik.http.middlewares.nextcloud-redirect.redirectscheme.scheme=https"
+      - "traefik.http.middlewares.nextcloud-redirect.redirectscheme.permanent=true"
+      - "traefik.http.middlewares.nextcloud-headers.headers.customRequestHeaders.X-Forwarded-Proto=https"
+      - "traefik.http.middlewares.nextcloud-headers.headers.stsSeconds=15552000"
+      - "traefik.http.middlewares.nextcloud-headers.headers.stsIncludeSubdomains=true"
+      - "traefik.http.middlewares.nextcloud-headers.headers.stsPreload=true"
+      - "traefik.http.services.nextcloud.loadbalancer.server.port=80"
+    networks:
+      - traefik
+      - storage
+    depends_on:
+      - nextcloud
+
+  # ==========================================
+  # Nextcloud Init (runs once to setup config)
+  # ==========================================
+  nextcloud-init:
+    image: nextcloud:29.0.7-fpm-alpine
+    container_name: nextcloud-init
+    restart: "no"
+    environment:
+      - NEXTCLOUD_ADMIN_USER=${NEXTCLOUD_ADMIN_USER}
+      - NEXTCLOUD_ADMIN_PASSWORD=${NEXTCLOUD_ADMIN_PASSWORD}
+    volumes:
+      - nextcloud-config:/var/www/html/config
+      - ./config/nextcloud:/docker-entrypoint-hooks.d:ro
+    entrypoint: ["/bin/sh", "-c"]
+    command: >
+      "cp /docker-entrypoint-hooks.d/config.php /var/www/html/config/config.php 2>/dev/null || true;
+       chown -R www-data:www-data /var/www/html/config"
+    networks:
+      - storage
+
+  # ==========================================
+  # MinIO
+  # ==========================================
+  minio:
+    image: minio/minio:RELEASE.2024-09-22T00-33-43Z
+    container_name: minio
+    restart: unless-stopped
+    command: server /data --console-address ":9001"
+    environment:
+      - MINIO_ROOT_USER=${MINIO_ROOT_USER}
+      - MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
+      - MINIO_BROWSER_REDIRECT_URL=https://minio.${DOMAIN}
+      - MINIO_SERVER_URL=https://s3.${DOMAIN}
+    volumes:
+      - minio-data:/data
+      - ./scripts/minio-init.sh:/minio-init.sh:ro
+    labels:
+      - "traefik.enable=true"
+      # Console
+      - "traefik.http.routers.minio-console.rule=Host(`minio.${DOMAIN}`)"
+      - "traefik.http.routers.minio-console.entrypoints=websecure"
+      - "traefik.http.routers.minio-console.tls.certresolver=letsencrypt"
+      - "traefik.http.routers.minio-console.service=minio-console"
+      - "traefik.http.services.minio-console.loadbalancer.server.port=9001"
+      # API
+      - "traefik.http.routers.minio-api.rule=Host(`s3.${DOMAIN}`)"
+      - "traefik.http.routers.minio-api.entrypoints=websecure"
+      - "traefik.http.routers.minio-api.tls.certresolver=letsencrypt"
+      - "traefik.http.routers.minio-api.service=minio-api"
+      - "traefik.http.services.minio-api.loadbalancer.server.port=9000"
+    networks:
+      - traefik
+      - storage
+   