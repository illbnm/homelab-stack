# Databases Stack

> Shared relational database services: PostgreSQL, Redis, MariaDB + admin UIs

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| PostgreSQL | postgres:16-alpine | 5432 | Primary relational DB (Gitea, Outline, etc.) |
| Redis | redis:7-alpine | 6379 | Caching + session storage |
| MariaDB | mariadb:11.4 | 3306 | MySQL-compatible DB (Nextcloud, BookStack) |
| pgAdmin | dpage/pgadmin4:8.11 | 80 (via Traefik) | PostgreSQL admin UI |
| Redis Commander | rediscommander/redis-commander:latest | 8081 (via Traefik) | Redis admin UI |

## Quick Start

```bash
# Copy environment config
cp .env.example ../../.env
# Edit ../../.env with your passwords

# Launch
docker compose up -d
```

## Configuration

### PostgreSQL

- **Image**: `postgres:16-alpine`
- **Persistence**: `postgres-data` volume
- **Init**: Auto-creates service databases on first start (`initdb/`)
- **Healthcheck**: `pg_isready`
- **Traefik**: Disabled (internal only)

### Redis

- **Image**: `redis:7-alpine`
- **Persistence**: AOF enabled (`appendfsync everysec`)
- **Memory**: 512mb max, `allkeys-lru` eviction policy
- **Traefik**: Disabled (internal only)

### MariaDB

- **Image**: `mariadb:11.4`
- **Persistence**: `mariadb-data` volume
- **Root login**: Disabled (use `mariadb` user)
- **Init**: Auto-creates per-service DBs on first start (`initdb-mysql/`)
- **Traefik**: Disabled (internal only)

### phpMyAdmin

- **Access**: `http://phpmyadmin.${DOMAIN}` (requires login)
- **Hosts**: postgres, redis, mariadb
- **Upload limit**: 64M
- **Network**: `databases` + `proxy` (accessible via browser)

## Backups

Automated GPG-encrypted backups using the provided scripts.

### Setup Backup Directory

```bash
sudo mkdir -p /opt/homelab/backups/postgres /opt/homelab/backups/mariadb
sudo chown -R $PUID:$PGID /opt/homelab/backups
```

### PostgreSQL Backup

```bash
# Manual backup
./config/databases/backup-postgres.sh

# Automated (add to crontab)
0 2 * * * /opt/homelab/homelab-stack/config/databases/backup-postgres.sh >> /opt/homelab/backups/postgres/backup.log
```

### MariaDB Backup

```bash
# Manual backup
./config/databases/backup-mariadb.sh

# Automated (add to crontab)
0 3 * * * /opt/homelab/homelab-stack/config/databases/backup-mariadb.sh >> /opt/homelab/backups/mariadb/backup.log
```

### Restore from Backup

```bash
# Decrypt and restore PostgreSQL
gpg --decrypt --passphrase "$POSTGRES_BACKUP_PASSWORD" postgres_20260326_020000.sql.gz.gpg | zcat | docker exec -i homelab-postgres psql -U postgres

# Decrypt and restore MariaDB
gpg --decrypt --passphrase "$MARIADB_BACKUP_PASSWORD" mariadb_20260326_030000.sql.gz.gpg | zcat | docker exec -i homelab-mariadb mariadb -u root -p"$MARIADB_ROOT_PASSWORD"
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `POSTGRES_ROOT_PASSWORD` | Yes | Master PostgreSQL password |
| `REDIS_PASSWORD` | Yes | Redis authentication |
| `MARIADB_ROOT_PASSWORD` | Yes | MariaDB root password |
| `POSTGRES_BACKUP_PASSWORD` | Yes | GPG encryption for PostgreSQL backups |
| `MARIADB_BACKUP_PASSWORD` | Yes | GPG encryption for MariaDB backups |
| `NEXTCLOUD_DB_PASSWORD` | No | Nextcloud MySQL database |
| `GITEA_DB_PASSWORD` | No | Gitea PostgreSQL database |
| `OUTLINE_DB_PASSWORD` | No | Outline PostgreSQL database |
| `BOOKSTACK_DB_PASSWORD` | No | BookStack MariaDB database |

## Auto-Created Databases

On first start, the following databases and users are automatically created:

| Database | User | For Service |
|----------|------|-------------|
| `nextcloud` | `nextcloud` | Nextcloud (PostgreSQL) |
| `gitea` | `gitea` | Gitea |
| `outline` | `outline` | Outline |
| `vaultwarden` | `vaultwarden` | Vaultwarden (optional PostgreSQL) |
| `bookstack` | `bookstack` | BookStack (MariaDB) |
| `nextcloud_mysql` | `nextcloud` | Nextcloud (MariaDB variant) |

## Network

- `databases`: Internal bridge network for inter-service communication
- `proxy`: External network for Traefik access (phpMyAdmin only)
