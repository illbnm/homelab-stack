# Database Layer

Shared database services for the homelab stack.

**Components:**
- [PostgreSQL 16](https://www.postgresql.org/) — Primary relational database (Alpine, minimal footprint)
- [Redis 7](https://redis.io/) — In-memory cache & message broker
- [pgAdmin 4](https://www.pgadmin.org/) — Optional web UI for PostgreSQL management

## Architecture

Both databases run on an internal `db` network and are **not exposed publicly**.
Other stacks connect by joining the `db` network:

```yaml
networks:
  db:
    external: true
```

## Quick Start

```bash
cp .env.example .env
nano .env  # Set strong passwords
docker compose up -d

# Verify
docker compose ps
docker compose logs --tail 20
```

## Connecting Other Services

Add to any service's `docker-compose.yml`:

```yaml
# PostgreSQL connection
environment:
  - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}

# Redis connection
  - REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379

networks:
  - db  # Join the shared db network
```

## pgAdmin (Optional)

pgAdmin is disabled by default. Start it when needed:

```bash
docker compose --profile admin up -d pgadmin
# Access: https://pgadmin.YOUR_DOMAIN (LAN only)
# Stop when done:
docker compose --profile admin stop pgadmin
```

## Creating Per-Service Databases

For services that need their own database (recommended over sharing one DB):

```bash
docker exec -it postgres psql -U ${POSTGRES_USER} -c "
  CREATE USER nextcloud WITH PASSWORD 'secret';
  CREATE DATABASE nextcloud OWNER nextcloud;
"
```

Or place SQL files in `./init/` — they run automatically on first start.

## Backup

```bash
# PostgreSQL dump
docker exec postgres pg_dump -U ${POSTGRES_USER} ${POSTGRES_DB} | gzip > backup_$(date +%Y%m%d).sql.gz

# Redis dump (RDB already persisted in volume)
docker exec redis redis-cli -a ${REDIS_PASSWORD} SAVE
```
