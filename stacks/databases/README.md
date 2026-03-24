# Databases Stack

Centralized PostgreSQL, Redis, and MariaDB services for the homelab.

## Services

| Container | Image | Port | Networks |
|-----------|-------|------|----------|
| `homelab-postgres` | postgres:16-alpine | 5432 | databases |
| `homelab-redis` | redis:7-alpine | 6379 | databases |
| `homelab-mariadb` | mariadb:11.4 | 3306 | databases |
| `homelab-pgadmin` | dpage/pgadmin4 | 5050 (mapped 30550) | proxy + databases |
| `homelab-redis-commander` | rediscommander/redis-commander | 8081 (mapped 30881) | proxy + databases |

## Quick Start

```bash
cd stacks/databases
cp ../base/.env .env
# Edit .env with real passwords

docker compose up -d
```

## Databases & Users

### PostgreSQL

Created automatically on first run via `initdb/01-init-databases.sh`:

| Database | Owner | Purpose |
|----------|-------|---------|
| `nextcloud` | `nextcloud` | Nextcloud cloud storage |
| `gitea` | `gitea` | Gitea self-hosted Git |
| `outline` | `outline` | Outline wiki/notes |
| `vaultwarden` | `vaultwarden` | Vaultwarden password manager |
| `bookstack` | `bookstack` | BookStack documentation |
| `authentik` | `authentik` | Authentik identity provider |
| `grafana` | `grafana` | Grafana metrics dashboards |

### Redis Multi-Database Assignments

Redis uses database indices `0`–`15`. This stack pre-initializes and assigns:

| DB | Service | Connection String Example |
|----|---------|--------------------------|
| 0 | Authentik | `redis://:${REDIS_PASSWORD}@homelab-redis:6379/0` |
| 1 | Outline | `redis://:${REDIS_PASSWORD}@homelab-redis:6379/1` |
| 2 | Gitea | `redis://:${REDIS_PASSWORD}@homelab-redis:6379/2` |
| 3 | Nextcloud | `redis://:${REDIS_PASSWORD}@homelab-redis:6379/3` |
| 4 | Grafana | `redis://:${REDIS_PASSWORD}@homelab-redis:6379/4` |

Add `?db=N` (e.g. `?db=3`) to the Redis URL in each service's `.env`.

### MariaDB

Created automatically via `initdb-mysql/01-init-databases.sql`:

| Database | User | Purpose |
|----------|------|---------|
| `bookstack` | `bookstack` | BookStack (MySQL variant) |
| `nextcloud_mysql` | `nextcloud` | Nextcloud (MySQL variant) |

## Connection Strings

### PostgreSQL

```
Host:     homelab-postgres
Port:     5432
User:     <service-user>
Password: <from .env>
Database: <service-db>
```

Examples:

```bash
# Nextcloud
postgresql://nextcloud:<NEXTCLOUD_DB_PASSWORD>@homelab-postgres:5432/nextcloud

# Gitea
postgresql://gitea:<GITEA_DB_PASSWORD>@homelab-postgres:5432/gitea

# Outline
postgresql://outline:<OUTLINE_DB_PASSWORD>@homelab-postgres:5432/outline

# Authentik
postgresql://authentik:<AUTHENTIK_DB_PASSWORD>@homelab-postgres:5432/authentik

# Grafana
postgresql://grafana:<GRAFANA_DB_PASSWORD>@homelab-postgres:5432/grafana
```

### Redis

```
Host:     homelab-redis
Port:     6379
Password: <from REDIS_PASSWORD>
```

Example with database selection:

```bash
# Authentik (DB 0)
redis://:${REDIS_PASSWORD}@homelab-redis:6379/0

# Outline (DB 1)
redis://:${REDIS_PASSWORD}@homelab-redis:6379/1

# Gitea (DB 2)
redis://:${REDIS_PASSWORD}@homelab-redis:6379/2

# Nextcloud (DB 3)
redis://:${REDIS_PASSWORD}@homelab-redis:6379/3

# Grafana sessions (DB 4)
redis://:${REDIS_PASSWORD}@homelab-redis:6379/4
```

### MariaDB

```
Host:     homelab-mariadb
Port:     3306
User:     root
Password: <MARIADB_ROOT_PASSWORD>
```

Example:

```bash
# BookStack
mysql://bookstack:<BOOKSTACK_DB_PASSWORD>@homelab-mariadb:3306/bookstack
```

## Admin UIs

### pgAdmin (PostgreSQL)

Access: `https://pgadmin.homelab.local` (configure Traefik host rule)

```
Email:    admin@homelab.local  (or PGADMIN_EMAIL from .env)
Password: <PGADMIN_PASSWORD>
```

To connect to PostgreSQL from pgAdmin:
1. Add Server → Name: `homelab-postgres`
2. Host: `homelab-postgres` (Docker DNS name)
3. Port: `5432`
4. Username: `postgres` (or `${POSTGRES_ROOT_USER}`)
5. Password: `${POSTGRES_ROOT_PASSWORD}`

### Redis Commander (Redis)

Access: `https://rediscommander.homelab.local` (configure Traefik host rule)

```
HTTP User:     admin        (or REDIS_CMD_USER from .env)
HTTP Password: <REDIS_CMD_PASSWORD>
```

Redis authentication is handled automatically via the `REDIS_PASSWORD` env var.
Select the desired database (0–4) from the dropdown in the UI.

## Verifying Database Creation

### PostgreSQL

```bash
# Shell into postgres container
docker exec -it homelab-postgres psql -U postgres

# List databases
postgres=# SELECT datname FROM pg_database;

# List users
postgres=# SELECT usename FROM pg_user;

# Connect to a specific database
postgres=# \c nextcloud

# List tables in Outline
nextcloud=# SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';
```

### Redis

```bash
# Shell into redis container
docker exec -it homelab-redis sh

# Verify databases exist (Redis creates them on first key write)
redis-cli -a '<REDIS_PASSWORD>' info keyspace

# Example output:
# db0: keys=0,expires=0,avg_ttl=0
# db1: keys=0,expires=0,avg_ttl=0
# db2: keys=0,expires=0,avg_ttl=0
# db3: keys=0,expires=0,avg_ttl=0
# db4: keys=0,expires=0,avg_ttl=0

# Switch to DB and verify
redis-cli -a '<REDIS_PASSWORD>' -n 1 ping
# Should return: PONG
```

### MariaDB

```bash
# Shell into mariadb container
docker exec -it homelab-mariadb mariadb -u root -p

# List databases
MariaDB [(none)]> SHOW DATABASES;

# List users
MariaDB [(none)]> SELECT user, host FROM mysql.user;
```

## Network Isolation

- **PostgreSQL, Redis, MariaDB** are on the `databases` bridge network only — not exposed to the proxy network
- **pgAdmin and Redis Commander** are on both `proxy` (for web access) and `databases` (to reach DB containers)
- All database containers have `traefik.enable=false` to prevent accidental exposure

## Idempotency

The PostgreSQL init script (`initdb/01-init-databases.sh`) is idempotent:

- It checks for existing users/databases before creating them
- Safe to re-run: `docker compose up -d` after editing the script will **not** re-trigger initialization (initdb scripts only run on first `pg_initdb` of the volume)
- To force re-initialization: `docker compose down -v` to destroy volumes, then `docker compose up -d`

## Health Checks

All services have health checks. Use `docker compose ps` to verify:

```
NAME                STATUS
homelab-postgres    Up (healthy)
homelab-redis       Up (healthy)
homelab-mariadb     Up (healthy)
homelab-pgadmin     Up (healthy)
homelab-redis-commander   Up (healthy)
```
