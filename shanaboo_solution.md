 ```diff
--- a/.env.example
+++ b/.env.example
@@ -0,0 +0,0 @@
+# ============================================
+# Database Stack Configuration
+# ============================================
+
+# PostgreSQL
+POSTGRES_ROOT_PASSWORD=changeme_postgres_root
+
+# Redis
+REDIS_PASSWORD=changeme_redis
+
+# MariaDB
+MARIADB_ROOT_PASSWORD=changeme_mariadb_root
+
+# pgAdmin
+PGADMIN_EMAIL=admin@example.com
+PGADMIN_PASSWORD=changeme_pgadmin
+
+# Service Database Passwords
+NEXTCLOUD_DB_PASSWORD=changeme_nextcloud_db
+GITEA_DB_PASSWORD=changeme_gitea_db
+OUTLINE_DB_PASSWORD=changeme_outline_db
+AUTHENTIK_DB_PASSWORD=changeme_authentik_db
+GRAFANA_DB_PASSWORD=changeme_grafana_db
+
+# ============================================
+# MinIO Backup (Optional)
+# ============================================
+MINIO_ENDPOINT=minio:9000
+MINIO_ACCESS_KEY=
+MINIO_SECRET_KEY=
+MINIO_BUCKET=backups
+
--- /dev/null
+++ b/stacks/databases/docker-compose.yml
@@ -0,0 +1,0 @@
+---
+# ==============================================================================
+# Database Stack — Shared PostgreSQL, Redis, MariaDB + Management UIs
+# ==============================================================================
+
+services:
+  # ==========================================================================
+  # PostgreSQL — Primary multi-tenant database
+  # ==========================================================================
+  postgres:
+    image: postgres:16.4-alpine
+    container_name: postgres
+    restart: unless-stopped
+    environment:
+      POSTGRES_USER: postgres
+      POSTGRES_PASSWORD: ${POSTGRES_ROOT_PASSWORD}
+      PGDATA: /var/lib/postgresql/data/pgdata
+    volumes:
+      - postgres_data:/var/lib/postgresql/data
+      - ./init-databases.sh:/docker-entrypoint-initdb.d/init-databases.sh:ro
+    networks:
+      - internal
+    healthcheck:
+      test: ["CMD-SHELL", "pg_isready -U postgres"]
+      interval: 10s
+      timeout: 5s
+      retries: 5
+      start_period: 30s
+
+  # ==========================================================================
+  # Redis — Cache / Queue
+  # ==========================================================================
+  redis:
+    image: redis:7.4.0-alpine
+    container_name: redis
+    restart: unless-stopped
+    command: >
+      sh -c "redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes"
+    volumes:
+      - redis_data:/data
+    networks:
+      - internal
+    healthcheck:
+      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
+      interval: 10s
+      timeout: 5s
+      retries: 5
+      start_period: 10s
+
+  # ==========================================================================
+  # MariaDB — MySQL-compatible (for Nextcloud and other legacy services)
+  # ==========================================================================
+  mariadb:
+    image: mariadb:11.5.2
+    container_name: mariadb
+    restart: unless-stopped
+    environment:
+      MYSQL_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD}
+      MYSQL_DATABASE: nextcloud
+      MYSQL_USER: nextcloud
+      MYSQL_PASSWORD: ${NEXTCLOUD_DB_PASSWORD}
+    volumes:
+      - mariadb_data:/var/lib/mysql
+    networks:
+      - internal
+    healthcheck:
+      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
+      interval: 10s
+      timeout: 5s
+      retries: 5
+      start_period: 30s
+
+  # ==========================================================================
+  # pgAdmin — PostgreSQL Management UI
+  # ==========================================================================
+  pgadmin:
+    image: dpage/pgadmin4:8.11
+    container_name: pgadmin
+    restart: unless-stopped
+    environment:
+      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_EMAIL}
+      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_PASSWORD}
+      PGADMIN_CONFIG_SERVER_MODE: "False"
+      PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED: "False"
+    volumes:
+      - pgadmin_data:/var/lib/pgadmin
+      - ./pgadmin-servers.json:/pgadmin4/servers.json:ro
+    networks:
+      - internal
+      - proxy
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.pgadmin.rule=Host(`pgadmin.${DOMAIN:-localhost}`)"
+      - "traefik.http.routers.pgadmin.entrypoints=websecure"
+      - "traefik.http.routers.pgadmin.tls.certresolver=letsencrypt"
+      - "traefik.http.services.pgadmin.loadbalancer.server.port=80"
+    depends_on:
+      postgres:
+        condition: service_healthy
+
+  # ==========================================================================
+  # Redis Commander — Redis Management UI
+  # ==========================================================================
+  redis-commander:
+    image: rediscommander/redis-commander:latest-sha
+    container_name: redis-commander
+    restart: unless-stopped
+    environment:
+      REDIS_HOST: redis
+      REDIS_PORT: 6379
+      REDIS_PASSWORD: ${REDIS_PASSWORD}
+    networks:
+      - internal
+      - proxy
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.redis-commander.rule=Host(`redis-commander.${DOMAIN:-localhost}`)"
+      - "traefik.http.routers.redis-commander.entrypoints=websecure"
+      - "traefik.http.routers.redis-commander.tls.certresolver=letsencrypt"
+      - "traefik.http.services.redis-commander.loadbalancer.server.port=8081"
+    depends_on:
+      redis:
+        condition: service_healthy
+
+# ==============================================================================
+# Volumes
+# ==============================================================================
+volumes:
+  postgres_data:
+  redis_data:
+  mariadb_data:
+  pgadmin_data:
+
+# ==============================================================================
+# Networks
+# ==============================================================================
+networks:
+  internal:
+    name: internal
+    driver: bridge
+  proxy:
+    external: true
+
--- /dev/null
+++ b/stacks/databases/init-databases.sh
@@ -0,0 +1,0 @@
+#!/bin/bash
+# ==============================================================================
+# init-databases.sh — Idempotent PostgreSQL multi-tenant database initialization
+# ==============================================================================
+#
+# This script creates isolated databases and users for each service.
+# It is designed to be idempotent — safe to run multiple times.
+#
+# Usage:
+#   docker compose exec postgres /docker-entrypoint-initdb.d/init-databases.sh
+#   OR (from host):
+#   docker compose exec