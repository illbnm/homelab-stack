# Databases Stack

> Shared PostgreSQL, Redis, MariaDB, and phpMyAdmin for the HomeLab.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| PostgreSQL | postgres:16.4-alpine | 5432 | Shared relational DB for Gitea, Outline, Authentik, etc. |
| Redis | redis:7.4.0-alpine | 6379 | Shared cache/session store for Outline, etc. |
| MariaDB | mariadb:11.4.2 | 3306 | MySQL-compatible DB for Nextcloud, etc. |
| phpMyAdmin | phpmyadmin:5.2.1 | 80 | DB management UI (via phpmyadmin.${DOMAIN}) |

## Quick Start

```bash
cd stacks/databases
cp .env.example .env
nano .env  # Fill in passwords
docker compose up -d
```

## Configuration

### Environment Variables

```env
# PostgreSQL
POSTGRES_ROOT_USER=postgres
POSTGRES_DB_PASSWORD=         # REQUIRED
POSTGRES_BACKUP_PASSWORD=     # GPG encryption password (optional)

# Redis
REDIS_PASSWORD=                # REQUIRED

# MariaDB
MARIADB_ROOT_PASSWORD=         # REQUIRED
MARIADB_PASSWORD=             # REQUIRED: application user password

# phpMyAdmin
# Access via: https://phpmyadmin.${DOMAIN}
```

### Connection Info

| Service | Host | Port | User |
|---------|------|------|------|
| PostgreSQL | homelab-postgres | 5432 | postgres / per-service users |
| Redis | homelab-redis | 6379 | default |
| MariaDB | homelab-mariadb | 3306 | mariadb (app) / per-service users |
| phpMyAdmin | phpmyadmin.${DOMAIN} | 443 | mariadb |

### Resource Limits

| Service | Memory Limit |
|---------|-------------|
| PostgreSQL | 1GB |
| Redis | 512MB |
| MariaDB | 1GB |
| phpMyAdmin | 256MB |

## Backups

Backup scripts are located in `config/databases/`:

```bash
# PostgreSQL backup
./config/databases/backup-postgres.sh /opt/homelab/backups/postgres

# MariaDB backup
./config/databases/backup-mariadb.sh /opt/homelab/backups/mariadb
```

### Cron Setup

```bash
# Add to crontab (daily at 2am for Postgres, 3am for MariaDB)
crontab -e
# 0 2 * * * cd /opt/homelab/stacks/databases && ./config/backup-postgres.sh /opt/homelab/backups/postgres >> /var/log/postgres-backup.log 2>&1
# 0 3 * * * cd /opt/homelab/stacks/databases && ./config/backup-mariadb.sh /opt/homelab/backups/mariadb >> /var/log/mariadb-backup.log 2>&1
```

## Security Notes

- PostgreSQL and Redis are **not exposed** to external traffic (Traefik labels disabled)
- MariaDB root login is **disabled** — use the `mariadb` application user
- phpMyAdmin is exposed via subdomain and accessible only within your network
- All passwords must be set via environment variables before first start
