# Database Stack

Shared database services: PostgreSQL, Redis, MariaDB, plus management UIs (pgAdmin, Redis Commander).

## Services

| Service | Image | Purpose | Access |
|---------|-------|---------|--------|
| PostgreSQL | `postgres:16-alpine` | Primary relational DB | `homelab-postgres:5432` (internal) |
| Redis | `redis:7-alpine` | Cache & message broker | `homelab-redis:6379` (internal, requires password) |
| MariaDB | `mariadb:11.4` | MySQL-compatible DB | `homelab-mariadb:3306` (internal) |
| pgAdmin | `dpage/pgadmin4:8.11` | PostgreSQL admin UI | `https://pgadmin.${DOMAIN}` |
| Redis Commander | `rediscommander/redis-commander:latest` | Redis admin UI | `https://redis.${DOMAIN}` |

**Note:** Database containers are **not** exposed to the host network; only internal Docker network. Management UIs are exposed via Traefik with HTTPS.

## Initialization

1. Copy `.env.example` to `.env` and fill in all required passwords.
2. Start the stack: `docker compose up -d`.
3. Run the initialization script to create role/databases for each service:

```bash
./scripts/init-databases.sh
```

The script is idempotent and can be re-run safely.

## Environment Variables

All passwords and configuration are defined in `../.env` (repo root) and referenced here. Key variables:

- `POSTGRES_ROOT_PASSWORD`
- `REDIS_PASSWORD`
- `MARIADB_ROOT_PASSWORD`
- Service-specific DB passwords: `NEXTCLOUD_DB_PASSWORD`, `GITEA_DB_PASSWORD`, `OUTLINE_DB_PASSWORD`, `VAULTWARDEN_DB_PASSWORD`, `BOOKSTACK_DB_PASSWORD`, `AUTHENTIK_DB_PASSWORD`, `GRAFANA_DB_PASSWORD`.

pgAdmin UI credentials:

- `PGADMIN_EMAIL`
- `PGADMIN_PASSWORD`

## Connection Examples

### PostgreSQL (from other stacks)

```yaml
# In other docker-compose.yml files
environment:
  - POSTGRES_HOST=homelab-postgres
  - POSTGRES_PORT=5432
  - POSTGRES_USER=<service_user>
  - POSTGRES_PASSWORD=<service_password>
```

### Redis

```yaml
environment:
  - REDIS_HOST=homelab-redis
  - REDIS_PORT=6379
  - REDIS_PASSWORD=${REDIS_PASSWORD}
```

### MariaDB (BookStack)

```yaml
environment:
  - DB_HOST=homelab-mariadb
  - DB_PORT=3306
  - DB_DATABASE=bookstack
  - DB_USERNAME=bookstack
  - DB_PASSWORD=${BOOKSTACK_DB_PASSWORD}
```

## Management UIs

- **pgAdmin**: https://pgadmin.${DOMAIN}
  - Login with the email/password set in `PGADMIN_EMAIL` / `PGADMIN_PASSWORD`.
  - Add servers manually if needed (predefined servers not auto-configured).

- **Redis Commander**: https://redis.${DOMAIN}
  - Shows connection to local Redis instance.

## Backup

Database backups are handled by the central `scripts/backup-databases.sh` script.

```bash
./scripts/backup-databases.sh --all
```

Backups are stored in `backups/databases/` with timestamps.

## Security

- All database traffic stays within the internal `databases` network.
- No database ports are published to the host.
- Management UIs are protected by Traefik and (optionally) Authentik OIDC.
