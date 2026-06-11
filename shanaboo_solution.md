 ```diff
--- a/.env.example
+++ b/.env.example
@@ -0,0 +1,21 @@
+# Database Stack Configuration
+# ============================
+
+# PostgreSQL
+POSTGRES_ROOT_PASSWORD=changeme-postgres-root
+
+# Redis
+REDIS_PASSWORD=changeme-redis
+
+# MariaDB
+MARIADB_ROOT_PASSWORD=changeme-mariadb-root
+
+# pgAdmin
+PGADMIN_EMAIL=admin@example.com
+PGADMIN_PASSWORD=changeme-pgadmin
+
+# Service Database Passwords
+NEXTCLOUD_DB_PASSWORD=changeme-nextcloud-db
+GITEA_DB_PASSWORD=changeme-gitea-db
+OUTLINE_DB_PASSWORD=changeme-outline-db
+AUTHENTIK_DB_PASSWORD=changeme-authentik-db
+GRAFANA_DB_PASSWORD=changeme-grafana-db
+
--- /dev/null
+++ b/stacks/databases/docker-compose.yml
@@ -0,0 +1,168 @@
+services:
+  # PostgreSQL - Primary multi-tenant database
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
+      - ./scripts/init-databases.sh:/docker-entrypoint-initdb.d/init-databases.sh:ro
+    networks:
+      - internal
+    healthcheck:
+      test: ["CMD-SHELL", "pg_isready -U postgres"]
+      interval: 10s
+      timeout: 5s
+      retries: 5
+      start_period: 30s
+    security_opt:
+      - no-new-privileges:true
+
+  # Redis - Cache/Queue
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
+    security_opt:
+      - no-new-privileges:true
+
+  # MariaDB - MySQL compatible (for Nextcloud optional)
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
+    security_opt:
+      - no-new-privileges:true
+
+  # pgAdmin - PostgreSQL management UI
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
+      - ./config/servers.json:/pgadmin4/servers.json:ro
+    networks:
+      - internal
+      - proxy
+    labels:
+      - "traefik.enable=true"
+      - "traefik.http.routers.pgadmin.rule=Host(`pgadmin.${DOMAIN:-localhost}`)"
+      - "traefik.http.routers.pgadmin.entrypoints=websecure"
+      - "traefik.http.routers.pgadmin.tls.certresolver=letsencrypt"
+      - "traefik.http.routers.pgadmin.middlewares=authentik@docker"
+      - "traefik.http.services.pgadmin.loadbalancer.server.port=80"
+    depends_on:
+      postgres:
+        condition: service_healthy
+    security_opt:
+      - no-new-privileges:true
+
+  # Redis Commander - Redis management UI
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
+      - "traefik.http.routers.redis-commander.middlewares=authentik@docker"
+      - "traefik.http.services.redis-commander.loadbalancer.server.port=8081"
+    depends_on:
+      redis:
+        condition: service_healthy
+    security_opt:
+      - no-new-privileges:true
+
+volumes:
+  postgres_data:
+    driver: local
+  redis_data:
+    driver: local
+  mariadb_data:
+    driver: local
+  pgadmin_data:
+    driver: local
+
+networks:
+  internal:
+    driver: bridge
+  proxy:
+    external: true
+
--- /dev/null
+++ b/stacks/databases/scripts/init-databases.sh
@@ -0,0 +1,56 @@
+#!/bin/bash
+set -euo pipefail
+
+# PostgreSQL Multi-Tenant Database Initialization Script
+# This script is idempotent - safe to run multiple times
+
+DB_USER="${POSTGRES_USER:-postgres}"
+DB_HOST="${POSTGRES_HOST:-localhost}"
+DB_PORT="${POSTGRES_PORT:-5432}"
+
+# Function to create database and user idempotently
+create_db() {
+    local db_name="$1"
+    local db_password="$2"
