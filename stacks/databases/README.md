# Database Stack

Shared PostgreSQL 16 + Redis 7 + MariaDB 11.

## Services

| Service | Version | URL/Port | Purpose |
|---------|---------|----------|---------|
| PostgreSQL | 16-alpine | `postgres.${DOMAIN}` | Relational DB |
| Redis | 7-alpine | `redis.${DOMAIN}` | Cache |
| MariaDB | 11 | `mariadb.${DOMAIN}` | MySQL-compatible DB |

## Quick Start

```bash
docker compose -f stacks/databases/docker-compose.yml up -d
```

Available on `databases` Docker network for internal use by other stacks.
