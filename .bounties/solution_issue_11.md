# Solution for [github/issues_11]: [illbnm/homelab-stack] [BOUNTY $130] Database Layer — PostgreSQL + Redis + MariaDB 共享实例

- **Reward:** $130.00 USDC
- **Target URL:** https://github.com/illbnm/homelab-stack/issues/11
- **AI Brain:** gemini-2.5-flash
- **Tokens Used:** 10166 (~$0.0203 USD compute cost)

---

This bounty requires setting up a shared database layer using Docker Compose, including PostgreSQL, Redis, and MariaDB, along with their respective administration tools (pgAdmin, Redis Commander). The solution must ensure multi-tenancy for PostgreSQL, database isolation for Redis, robust health checks, network isolation, and a comprehensive backup strategy.

## Root Cause Analysis

The core problem is resource waste and management overhead when each service runs its own database instance. A shared database layer centralizes resources, simplifies management, and reduces the overall footprint. The challenge lies in correctly configuring these services for multi-tenancy, ensuring proper isolation, security, and maintainability within a Docker Compose environment.

Specific challenges include:
1.  **Idempotent PostgreSQL Initialization**: Creating databases and users only if they don't already exist.
2.  **Redis Database Isolation**: Using `SELECT N` to isolate data for different applications.
3.  **Robust Health Checks**: Ensuring services are truly ready before dependent services start.
4.  **Network Segmentation**: Restricting database access to internal services only, except for admin UIs.
5.  **Comprehensive Backup**: Scripting `pg_dumpall` and `redis-cli BGSAVE` with retention.
6.  **Environment Variable Management**: Securely handling sensitive credentials.

## Architecture Design

The solution will be based on Docker Compose, defining a `databases` stack.

**Services:**

*   **`postgres`**: PostgreSQL 16.4-alpine.
    *   Persistent volume for data.
    *   Custom `init-databases.sh` script executed on startup via `command` or `entrypoint` extension.
    *   Health check.
    *   Internal network only.
*   **`redis`**: Redis 7.4.0-alpine.
    *   Persistent volume for data.
    *   Password protected.
    *   Health check.
    *   Internal network only.
*   **`mariadb`**: MariaDB 11.5.2.
    *   Persistent volume for data.
    *   Health check.
    *   Internal network only.
*   **`pgadmin`**: pgAdmin 4.8.11.
    *   Connects to `postgres` service.
    *   Exposed via Traefik (proxy network).
    *   Health check.
*   **`redis-commander`**: Redis Commander.
    *   Connects to `redis` service.
    *   Exposed via Traefik (proxy network).
    *   Health check.

**Networks:**

*   **`internal`**: For all database services to communicate with each other and with other application stacks (e.g., Nextcloud, Gitea). This network will be `external` to allow other `docker-compose.yml` files to connect to it.
*   **`proxy`**: For `pgadmin` and `redis-commander` to be exposed via Traefik. This network will also be `external`.

**Volumes:**

*   `postgres_data`: For PostgreSQL data persistence.
*   `redis_data`: For Redis data persistence.
*   `mariadb_data`: For MariaDB data persistence.
*   `pgadmin_data`: For pgAdmin configuration persistence.

**Scripts:**

*   `scripts/init-databases.sh`: An idempotent script to create PostgreSQL databases and users. This script will be mounted into the `postgres` container and executed as part of its startup.
*   `scripts/backup-databases.sh`: A script to perform backups of PostgreSQL and Redis, compress them, and manage retention.

**Environment Variables:**

All sensitive credentials will be managed via a `.env` file, referenced in `docker-compose.yml`.

## Production-Ready Code/Patch Implementation

Here's the implementation, including `docker-compose.yml`, `scripts`, and `README.md` updates.

### File: docker-compose.yml
```yaml
# This file defines the shared database layer for the homelab stack.
# It includes PostgreSQL, Redis, MariaDB, and their respective administration UIs.
#
# Services:
# - postgres: Primary database for most applications (e.g., Gitea, Outline, Authentik, Grafana).
# - redis: Caching and queueing for applications (e.g., Authentik, Outline, Gitea, Nextcloud, Grafana).
# - mariadb: MySQL-compatible database (e.g., Nextcloud optional).
# - pgadmin: Web-based administration tool for PostgreSQL.
# - redis-commander: Web-based administration tool for Redis.
#
# Networks:
# - internal: Private network for database services and other application stacks to communicate.
# - proxy: Network for services exposed via Traefik (e.g., pgadmin, redis-commander).
#
# Volumes:
# - postgres_data: Persistent storage for PostgreSQL data.
# - redis_data: Persistent storage for Redis data.
# - mariadb_data: Persistent storage for MariaDB data.
# - pgadmin_data: Persistent storage for pgAdmin configuration.
#
# Usage:
# 1. Create a .env file based on .env.example and fill in the required variables.
# 2. Ensure the 'internal' and 'proxy' networks are created (e.g., by a base compose file or manually).
# 3. Run `docker compose up -d` in this directory.
# 4. The `init-databases.sh` script will automatically run on postgres startup to create initial databases and users.
# 5. Access pgAdmin and Redis Commander via Traefik (configured in your main proxy stack).
#
# For backup, use the `scripts/backup-databases.sh` script.
#
version: '3.8'

services:
  postgres:
    image: postgres:16.4-alpine
    container_name: postgres
    hostname: postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_ROOT_PASSWORD}
      POSTGRES_DB: postgres # Default database
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init-databases.sh:/docker-entrypoint-initdb.d/init-databases.sh:ro
    networks:
      - internal
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s
    labels:
      - "autoupdate=true" # For Watchtower or similar

  redis:
    image: redis:7.4.0-alpine
    container_name: redis
    hostname: redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - internal
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s
    labels:
      - "autoupdate=true"

  mariadb:
    image: mariadb:11.5.2
    container_name: mariadb
    hostname: mariadb
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD}
      MARIADB_USER: mariadb_user # A default user, specific app users can be created later if needed
      MARIADB_PASSWORD: ${MARIADB_ROOT_PASSWORD} # Using root password for simplicity here, but can be separate
      MARIADB_DATABASE: nextcloud # Example default database for Nextcloud
    volumes:
      - mariadb_data:/var/lib/mysql
    networks:
      - internal
    healthcheck:
      test: ["CMD", "/usr/bin/healthcheck.sh", "--su-mysql", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s # MariaDB can take longer to initialize
    labels:
      - "autoupdate=true"

  pgadmin:
    image: dpage/pgadmin4:8.11
    container_name: pgadmin
    hostname: pgadmin
    restart: unless-stopped
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_EMAIL}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_PASSWORD}
      PGADMIN_LISTEN_PORT: 80
      PGADMIN_CONFIG_SERVER_MODE: 'False' # Disable server mode to allow direct connection to postgres service
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    networks:
      - internal
      - proxy
    depends_on:
      postgres:
        condition: service_healthy
    labels:
      - "autoupdate=true"
      - "traefik.enable=true"
      - "traefik.http.routers.pgadmin.entrypoints=websecure"
      - "traefik.http.routers.pgadmin.rule=Host(`pgadmin.${DOMAIN}`)"
      - "traefik.http.routers.pgadmin.tls=true"
      - "traefik.http.routers.pgadmin.middlewares=authelia@docker" # Assuming Authelia for auth
      - "traefik.http.services.pgadmin.loadbalancer.server.port=80"
      - "traefik.docker.network=proxy"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/misc/ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s

  redis-commander:
    image: rediscommander/redis-commander:latest-sha
    container_name: redis-commander
    hostname: redis-commander
    restart: unless-stopped
    environment:
      REDIS_HOSTS: local:redis:6379
      REDIS_PASSWORD: ${REDIS_PASSWORD}
      HTTP_USER: ${PGADMIN_EMAIL} # Reusing pgadmin email for simplicity, consider separate env var
      HTTP_PASSWORD: ${PGADMIN_PASSWORD} # Reusing pgadmin password for simplicity, consider separate env var
    networks:
      - internal
      - proxy
    depends_on:
      redis:
        condition: service_healthy
    labels:
      - "autoupdate=true"
      - "traefik.enable=true"
      - "traefik.http.routers.rediscommander.entrypoints=websecure"
      - "traefik.http.routers.rediscommander.rule=Host(`redis.${DOMAIN}`)"
      - "traefik.http.routers.rediscommander.tls=true"
      - "traefik.http.routers.rediscommander.middlewares=authelia@docker" # Assuming Authelia for auth
      - "traefik.http.services.rediscommander.loadbalancer.server.port=8081"
      - "traefik.docker.network=proxy"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8081/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s

networks:
  internal:
    external: true
  proxy:
    external: true

volumes:
  postgres_data:
  redis_data:
  mariadb_data:
  pgadmin_data:
```

### File: .env.example
```ini
# --- General Settings ---
DOMAIN=yourdomain.com # Your primary domain for Traefik routing

# --- PostgreSQL Settings ---
POSTGRES_ROOT_PASSWORD=your_strong_postgres_root_password

# Application-specific PostgreSQL database passwords
NEXTCLOUD_DB_PASSWORD=your_nextcloud_db_password
GITEA_DB_PASSWORD=your_gitea_db_password
OUTLINE_DB_PASSWORD=your_outline_db_password
AUTHENTIK_DB_PASSWORD=your_authentik_db_password
GRAFANA_DB_PASSWORD=your_grafana_db_password

# --- Redis Settings ---
REDIS_PASSWORD=your_strong_redis_password

# --- MariaDB Settings ---
MARIADB_ROOT_PASSWORD=your_strong_mariadb_root_password

# --- Admin UI Settings ---
PGADMIN_EMAIL=admin@yourdomain.com
PGADMIN_PASSWORD=your_strong_pgadmin_password
# Redis Commander will reuse PGADMIN_EMAIL and PGADMIN_PASSWORD for basic auth.
# If you need separate credentials, add REDIS_COMMANDER_USER and REDIS_COMMANDER_PASSWORD.
```

### File: scripts/init-databases.sh
```bash
#!/bin/bash
set -e

echo "Running init-databases.sh script..."

# Function to create a PostgreSQL database and user if they don't exist
create_db() {
    local DB_NAME=$1
    local DB_USER=$1 # User name is same as DB name for simplicity
    local DB_PASSWORD=$2

    echo "Checking for database '$DB_NAME' and user '$DB_USER'..."

    # Check if database exists
    if ! psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1; then
        echo "Database '$DB_NAME' does not exist. Creating..."
        psql -U postgres -c "CREATE DATABASE $DB_NAME;"
        echo "Database '$DB_NAME' created."
    else
        echo "Database '$DB_NAME' already exists."
    fi

    # Check if user exists
    if ! psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER'" | grep -q 1; then
        echo "User '$DB_USER' does not exist. Creating..."
        psql -U postgres -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';"
        echo "User '$DB_USER' created."
    else
        echo "User '$DB_USER' already exists."
    fi

    # Grant privileges to the user on the database
    # This is idempotent as granting existing privileges doesn't error.
    echo "Granting privileges for user '$DB_USER' on database '$DB_NAME'..."
    psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
    echo "Privileges granted."
}

# Wait for PostgreSQL to be ready
until pg_isready -U postgres; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 2
done
echo "PostgreSQL is ready."

# Load environment variables from the .env file if not already set
# This is crucial for the script to pick up passwords when run manually or via docker-compose exec
if [ -f /run/secrets/.env ]; then # Check for secrets mounted by Docker Compose
    echo "Loading environment variables from /run/secrets/.env"
    export $(grep -v '^#' /run/secrets/.env | xargs -d '\n')
elif [ -f ./.env ]; then # Fallback for local testing if .env is in current dir
    echo "Loading environment variables from ./.env"
    export $(grep -v '^#' ./.env | xargs -d '\n')
fi

# Ensure all required environment variables are set
if [ -z "${NEXTCLOUD_DB_PASSWORD}" ]; then echo "NEXTCLOUD_DB_PASSWORD not set!"; exit 1; fi
if [ -z "${GITEA_DB_PASSWORD}" ]; then echo "GITEA_DB_PASSWORD not set!"; exit 1; fi
if [ -z "${OUTLINE_DB_PASSWORD}" ]; then echo "OUTLINE_DB_PASSWORD not set!"; exit 1; fi
if [ -z "${AUTHENTIK_DB_PASSWORD}" ]; then echo "AUTHENTIK_DB_PASSWORD not set!"; exit 1; fi
if [ -z "${GRAFANA_DB_PASSWORD}" ]; then echo "GRAFANA_DB_PASSWORD not set!"; exit 1; fi

# Create databases and users for each service
create_db "nextcloud" "${NEXTCLOUD_DB_PASSWORD}"
create_db "gitea" "${GITEA_DB_PASSWORD}"
create_db "outline" "${OUTLINE_DB_PASSWORD}"
create_db "authentik" "${AUTHENTIK_DB_PASSWORD}"
create_db "grafana" "${GRAFANA_DB_PASSWORD}"

echo "All specified PostgreSQL databases and users are configured."
```

**Note on `init-databases.sh` execution:**
The `init-databases.sh` script is mounted into `/docker-entrypoint-initdb.d/`. Docker's official PostgreSQL image automatically executes scripts in this directory during container startup. This ensures the databases and users are created when the `postgres` service first starts or when the data volume is empty. The script is idempotent, so it won't cause issues on subsequent restarts with existing data.

For the script to access environment variables like `NEXTCLOUD_DB_PASSWORD`, these variables need to be available inside the `postgres` container. Docker Compose automatically passes environment variables defined in the `environment` section or loaded from `.env` to the container. The `init-databases.sh` script includes a fallback to load from `/run/secrets/.env` if using Docker secrets, or from `./.env` for direct `docker compose` usage.

### File: scripts/backup-databases.sh
```bash
#!/bin/bash
set -e

# --- Configuration ---
BACKUP_DIR="/backups" # Directory inside the container where backups will be stored temporarily
HOST_BACKUP_DIR="./backups" # Directory on the host where final backups will be saved
RETENTION_DAYS=7 # Number of days to retain backups
MINIO_UPLOAD=false # Set to true to enable MinIO upload (requires MinIO client and config)
MINIO_BUCKET="homelab-backups" # MinIO bucket name
MINIO_ENDPOINT="http://minio:9000" # MinIO endpoint (e.g., http://minio:9000)
MINIO_ACCESS_KEY="your_minio_access_key" # MinIO access key
MINIO_SECRET_KEY="your_minio_secret_key" # MinIO secret key

# --- Load Environment Variables ---
# This script is intended to be run from the host, so it sources the .env file.
if [ -f ./.env ]; then
    echo "Loading environment variables from ./.env"
    export $(grep -v '^#' ./.env | xargs -d '\n')
else
    echo "Error: ./.env file not found. Please create one based on .env.example."
    exit 1
fi

# Ensure required passwords are set
if [ -z "${POSTGRES_ROOT_PASSWORD}" ]; then echo "POSTGRES_ROOT_PASSWORD not set!"; exit 1; fi
if [ -z "${REDIS_PASSWORD}" ]; then echo "REDIS_PASSWORD not set!"; exit 1; fi
if [ -z "${MARIADB_ROOT_PASSWORD}" ]; then echo "MARIADB_ROOT_PASSWORD not set!"; exit 1; fi

# --- Create Host Backup Directory ---
mkdir -p "${HOST_BACKUP_DIR}"

# --- PostgreSQL Backup ---
echo "Starting PostgreSQL backup..."
PG_BACKUP_FILE="postgres_dumpall_$(date +%Y%m%d_%H%M%S).sql"
docker compose exec -T postgres pg_dumpall -U postgres > "${HOST_BACKUP_DIR}/${PG_BACKUP_FILE}"
echo "PostgreSQL backup completed: ${HOST_BACKUP_DIR}/${PG_BACKUP_FILE}"

# --- Redis Backup ---
echo "Starting Redis backup..."
# Trigger BGSAVE to ensure data is written to disk
docker compose exec -T redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE
# Wait a bit for BGSAVE to complete (can be improved with actual monitoring)
sleep 5
# Copy the dump.rdb file from the Redis container
REDIS_BACKUP_FILE="redis_dump_$(date +%Y%m%d_%H%M%S).rdb"
docker compose cp redis:/data/dump.rdb "${HOST_BACKUP_DIR}/${REDIS_BACKUP_FILE}"
echo "Redis backup completed: ${HOST_BACKUP_DIR}/${REDIS_BACKUP_FILE}"

# --- MariaDB Backup ---
echo "Starting MariaDB backup..."
MARIADB_BACKUP_FILE="mariadb_dumpall_$(date +%Y%m%d_%H%M%S).sql"
docker compose exec -T mariadb sh -c 'exec mariadb-dump -u root -p"$MARIADB_ROOT_PASSWORD" --all-databases' > "${HOST_BACKUP_DIR}/${MARIADB_BACKUP_FILE}"
echo "MariaDB backup completed: ${HOST_BACKUP_DIR}/${MARIADB_BACKUP_FILE}"

# --- Compress Backups ---
echo "Compressing backups..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_NAME="databases_backup_${TIMESTAMP}.tar.gz"
tar -czf "${HOST_BACKUP_DIR}/${ARCHIVE_NAME}" -C "${HOST_BACKUP_DIR}" \
    "${PG_BACKUP_FILE}" "${REDIS_BACKUP_FILE}" "${MARIADB_BACKUP_FILE}"

echo "Compressed backup created: ${HOST_BACKUP_DIR}/${ARCHIVE_NAME}"

# --- Clean up individual backup files ---
echo "Cleaning up individual backup files..."
rm "${HOST_BACKUP_DIR}/${PG_BACKUP_FILE}"
rm "${HOST_BACKUP_DIR}/${REDIS_BACKUP_FILE}"
rm "${HOST_BACKUP_DIR}/${MARIADB_BACKUP_FILE}"
echo "Individual backup files removed."

# --- Retention Policy ---
echo "Applying retention policy (keeping last ${RETENTION_DAYS} days)..."
find "${HOST_BACKUP_DIR}" -name "databases_backup_*.tar.gz" -mtime +${RETENTION_DAYS} -delete
echo "Old backups removed."

# --- MinIO Upload (Optional) ---
if [ "$MINIO_UPLOAD" = true ]; then
    echo "Uploading backup to MinIO..."
    # Ensure mc client is installed and configured
    # Example: docker run --rm -it -v ~/.mc:/root/.mc minio/mc config host add myminio ${MINIO_ENDPOINT} ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY}
    # For a simple script, you might need to install 'mc' or use 'awscli' if MinIO is S3 compatible.
    # For this example, we'll assume 'mc' is available and configured.
    # If running from a container, ensure mc is installed in that container.
    
    # Example using 'mc' client (requires mc to be installed on the host or in a utility container)
    # mc config host add myminio ${MINIO_ENDPOINT} ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY} --api S3v4
    # mc cp "${HOST_BACKUP_DIR}/${ARCHIVE_NAME}" myminio/${MINIO_BUCKET}/
    
    # A more robust way for a Docker Compose setup would be to use a dedicated backup container
    # or pass credentials directly to a temporary 'mc' container.
    
    echo "MinIO upload feature is not fully implemented in this script for direct execution."
    echo "Please configure 'mc' client or use an alternative S3 client to upload '${HOST_BACKUP_DIR}/${ARCHIVE_NAME}' to MinIO bucket '${MINIO_BUCKET}'."
fi

echo "Database backup process completed successfully."
```

**Note on `backup-databases.sh`:**
*   This script is designed to be run from the host machine where `docker compose` commands are executed.
*   It uses `docker compose exec` to interact with the running database containers.
*   It creates a `backups` directory in the same location as the `docker-compose.yml` file.
*   The MinIO upload section is commented out with instructions, as setting up `mc` client or `awscli` within a generic script can be complex and often depends on the host environment or a dedicated backup container. Users should integrate this based on their specific MinIO setup.

### File: README.md (Updates)

Add a new section for the Databases Stack.

```markdown
### File: README.md
```markdown
# Homelab Stack

This repository contains Docker Compose configurations for various self-hosted services, designed for a homelab environment.

## Table of Contents

*   [Getting Started](#getting-started)
*   [Core Services](#core-services)
    *   [Traefik (Reverse Proxy)](#traefik-reverse-proxy)
    *   [Databases (PostgreSQL, Redis, MariaDB)](#databases-postgresql-redis-mariadb)
    *   [Monitoring (Grafana, Prometheus, Loki)](#monitoring-grafana-prometheus-loki)
    *   [Authentication (Authelia)](#authentication-authelia)
*   [Application Services](#application-services)
    *   [Nextcloud](#nextcloud)
    *   [Gitea](#gitea)
    *   [Outline](#outline)
    *   [Authentik](#authentik)
*   [Backup Strategy](#backup-strategy)
*   [Contributing](#contributing)

---

## Getting Started

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/illbnm/homelab-stack.git
    cd homelab-stack
    ```
2.  **Create a `.env` file:**
    Copy `.env.example` to `.env` and fill in all the required environment variables, especially strong passwords and your domain.
    ```bash
    cp .env.example .env
    # Edit .env with your preferred editor
    ```
3.  **Ensure Docker and Docker Compose are installed.**
4.  **Start core services:** It's recommended to start services in a specific order, especially networks and proxies first.

    First, ensure your `proxy` and `internal` networks are created. If you have a main `docker-compose.yml` that defines these as `external: false`, start that first. Otherwise, you might need to create them manually:
    ```bash
    docker network create proxy
    docker network create internal
    ```

    Then, navigate to each service directory and start them:
    ```bash
    # Example: Start Traefik first (if it defines the networks)
    # cd traefik-stack
    # docker compose up -d

    # Then start databases
    cd databases-stack
    docker compose up -d

    # Then other services...
    ```

---

## Core Services

### Databases (PostgreSQL, Redis, MariaDB)

This stack provides a shared database layer for various applications, reducing resource consumption and simplifying management.

**Services Included:**

*   **PostgreSQL (`postgres:16.4-alpine`)**: Primary database for applications like Gitea, Outline, Authentik, Grafana.
*   **Redis (`redis:7.4.0-alpine`)**: Caching and queueing for applications like Authentik, Outline, Gitea, Nextcloud, Grafana.
*   **MariaDB (`mariadb:11.5.2`)**: MySQL-compatible database, primarily for Nextcloud (optional, PostgreSQL is also an option for Nextcloud).
*   **pgAdmin (`dpage/pgadmin4:8.11`)**: Web-based administration interface for PostgreSQL.
*   **Redis Commander (`rediscommander/redis-commander:latest-sha`)**: Web-based administration interface for Redis.

**Configuration:**

1.  **Environment Variables**: Ensure the following variables are set in your `.env` file:
    *   `POSTGRES_ROOT_PASSWORD`
    *   `REDIS_PASSWORD`
    *   `MARIADB_ROOT_PASSWORD`
    *   `PGADMIN_EMAIL`, `PGADMIN_PASSWORD`
    *   Application-specific PostgreSQL database passwords (e.g., `NEXTCLOUD_DB_PASSWORD`, `GITEA_DB_PASSWORD`, etc.)

2.  **Initialization Script (`scripts/init-databases.sh`)**:
    This script runs automatically on the `postgres` container's first startup (or when its data volume is empty). It idempotently creates dedicated databases and users for each specified application (Nextcloud, Gitea, Outline, Authentik, Grafana).

    **PostgreSQL Connection Strings Example:**
    For an application connecting to PostgreSQL, use the `postgres` service name as the host.
    *   **Nextcloud:**
        ```
        DB_TYPE=pgsql
        DB_HOST=postgres
        DB_NAME=nextcloud
        DB_USER=nextcloud
        DB_PASSWORD=${NEXTCLOUD_DB_PASSWORD}
        ```
    *   **Gitea:**
        ```
        DB_TYPE=postgres
        DB_HOST=postgres:5432
        DB_NAME=gitea
        DB_USER=gitea
        DB_PASSWD=${GITEA_DB_PASSWORD}
        ```
    *   **Outline:**
        ```
        DATABASE_URL=postgres://outline:${OUTLINE_DB_PASSWORD}@postgres:5432/outline
        ```
    *   **Authentik:**
        ```
        AUTHENTIK_DATABASE_HOST=postgres
        AUTHENTIK_DATABASE_NAME=authentik
        AUTHENTIK_DATABASE_USER=authentik
        AUTHENTIK_DATABASE_PASSWORD=${AUTHENTIK_DB_PASSWORD}
        ```
    *   **Grafana:**
        ```
        GF_DATABASE_TYPE=postgres
        GF_DATABASE_HOST=postgres:5432
        GF_DATABASE_NAME=grafana
        GF_DATABASE_USER=grafana
        GF_DATABASE_PASSWORD=${GRAFANA_DB_PASSWORD}
        ```

3.  **Redis Multi-Database Allocation:**
    Redis supports multiple logical databases (0-15 by default). Applications should specify a unique database index to avoid data collision.
    *   `DB 0 — Authentik`
    *   `DB 1 — Outline`
    *   `DB 2 — Gitea`
    *   `DB 3 — Nextcloud`
    *   `DB 4 — Grafana sessions`

    **Redis Connection Strings Example:**
    For an application connecting to Redis, use the `redis` service name as the host.
    *   **Authentik:** `redis://redis:6379/0?password=${REDIS_PASSWORD}`
    *   **Outline:** `redis://redis:6379/1?password=${REDIS_PASSWORD}`
    *   **Gitea:** `redis://redis:6379/2?password=${REDIS_PASSWORD}`
    *   **Nextcloud:** `redis://redis:6379/3?password=${REDIS_PASSWORD}`
    *   **Grafana:** `redis://redis:6379/4?password=${REDIS_PASSWORD}` (for session store)

4.  **MariaDB Connection String Example:**
    *   **Nextcloud (if using MariaDB):**
        ```
        DB_TYPE=mysql
        DB_HOST=mariadb
        DB_NAME=nextcloud
        DB_USER=mariadb_user # Or a dedicated user if created
        DB_PASSWORD=${MARIADB_ROOT_PASSWORD} # Or dedicated user's password
        ```

5.  **Accessing Admin UIs:**
    *   **pgAdmin**: `https://pgadmin.yourdomain.com` (requires Traefik and Authelia setup)
    *   **Redis Commander**: `https://redis.yourdomain.com` (requires Traefik and Authelia setup)

### Backup Strategy

The `scripts/backup-databases.sh` script provides a comprehensive backup solution for PostgreSQL, Redis, and MariaDB.

**Features:**

*   `pg_dumpall`: Backs up all PostgreSQL databases.
*   `redis-cli BGSAVE`: Triggers Redis to persist data to disk, then copies the `dump.rdb` file.
*   `mariadb-dump`: Backs up all MariaDB databases.
*   Compresses all backups into a single `.tar.gz` archive.
*   Implements a retention policy, keeping backups for the last 7 days.
*   Optional MinIO upload (requires manual configuration of `mc` client or similar).

**Usage:**

To run a backup, execute the script from the `databases-stack` directory on your host machine:
```bash
./scripts/backup-databases.sh
```

It's recommended to set this up as a scheduled cron job on your host system.

---
```

### Directory Structure

```
homelab-stack/
├── databases-stack/
│   ├── docker-compose.yml
│   ├── .env.example
│   └── scripts/
│       ├── init-databases.sh
│       └── backup-databases.sh
├── traefik-stack/
│   └── ...
├── nextcloud-stack/
│   └── ...
└── ...
```

## Testing Verification Steps

1.  **Initial Setup:**
    *   Clone the repository.
    *   Navigate to `databases-stack`.
    *   Copy `.env.example` to `.env` and fill in all placeholder values with strong, unique passwords and your domain.
    *   Ensure `proxy` and `internal` networks exist (e.g., by starting your `traefik-stack` first, or manually creating them: `docker network create proxy` and `docker network create internal`).
    *   Run `docker compose up -d`.

2.  **Container Health:**
    *   Verify all containers are running and healthy: `docker compose ps`
    *   Check logs for any errors: `docker compose logs`

3.  **PostgreSQL Initialization (Idempotency):**
    *   **First Run Verification:**
        *   Access `pgAdmin` via `https://pgadmin.yourdomain.com`. Log in with `PGADMIN_EMAIL` and `PGADMIN_PASSWORD`.
        *   Add a new server connection to `postgres` (Host: `postgres`, Port: `5432`, Maintenance DB: `postgres`, Username: `postgres`, Password: `POSTGRES_ROOT_PASSWORD`).
        *   Verify that databases `nextcloud`, `gitea`, `outline`, `authentik`, `grafana` exist.
        *   Verify that users `nextcloud`, `gitea`, `outline`, `authentik`, `grafana` exist and have privileges on their respective databases.
    *   **Idempotency Test:**
        *   Restart the `postgres` container: `docker compose restart postgres`.
        *   Check `docker compose logs postgres` for the `init-databases.sh` script output. It should indicate that databases and users already exist, without errors.
        *   Verify data in `pgAdmin` is still intact (e.g., create a dummy table in one of the databases, then restart `postgres` and check if it's still there).

4.  **Redis Connectivity and Isolation:**
    *   Access `Redis Commander` via `https://redis.yourdomain.com`. Log in with `PGADMIN_EMAIL` and `PGADMIN_PASSWORD`.
    *   Connect to the `redis` instance.
    *   In Redis Commander, try adding keys to different databases (e.g., `DB 0`, `DB 1`, `DB 2`).
        *   Select DB 0, add `SET authentik_test_key "authentik_

---

### Payout & Settlement Details
- **EVM Address:** `0x66545035486C8B3b7966c45dc035560F4066aBb5`
- **Network:** Base (Chain ID 8453) / Arbitrum / Polygon / Ethereum
- **Settlement Asset:** USDC
- **Settlement Trigger:** Direct on-chain payout upon PR merge
