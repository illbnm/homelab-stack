# Databases Stack

Shared database infrastructure for HomeLab: PostgreSQL, Redis, MariaDB, pgAdmin, and Redis Commander.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| PostgreSQL | 16 | internal | Multi-tenant relational database |
| Redis | 7 | internal | Caching and session storage |
| MariaDB | 11.4 | internal | MySQL-compatible database |
| pgAdmin | 8.11 | `pgadmin.<DOMAIN>` | PostgreSQL admin UI |
| Redis Commander | latest | `redis.<DOMAIN>` | Redis admin UI |

## Architecture

```
┌──────────────────────────────────────────────┐
│              Databases Stack                   │
│                                               │
│  ┌─────────┐  ┌──────┐  ┌──────────┐        │
│  │PostgreSQL│  │Redis │  │ MariaDB  │        │
│  │  ( :5432)│  │:6379)│  │   (:3306)│        │
│  └───┬─────┘  └──┬───┘  └────┬─────┘        │
│      │           │           │               │
│      └───────────┴───────────┘               │
│                   │                          │
│         ┌─────────▼─────────┐                │
│         │  Internal Network  │                │
│         └─────────┬─────────┘                │
│                   │                          │
│     ┌─────────────┼─────────────┐           │
│     │             │             │             │
│  ┌──▼────┐   ┌──▼────┐   ┌─────▼────┐       │
│  │pgAdmin│   │Redis  │   │ Other    │       │
│  │UI     │   │Commander    │ Stacks   │       │
│  └───────┘   └────────┘   └──────────┘       │
└──────────────────────────────────────────────┘
```

## Prerequisites

- Base Infrastructure deployed first (creates `proxy` network)
- Docker >= 24.0 with Compose v2

## Quick Start

```bash
cd stacks/databases
cp .env.example .env
# Edit .env with strong passwords

docker compose up -d

# Initialize per-service databases
cd ../..
./scripts/init-databases.sh --wait
```

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `POSTGRES_ROOT_PASSWORD` | ✅ | PostgreSQL root password |
| `REDIS_PASSWORD` | ✅ | Redis requirepass |
| `MARIADB_ROOT_PASSWORD` | ✅ | MariaDB root password |
| `PGADMIN_EMAIL` | — | pgAdmin login email (default: admin@localhost) |
| `PGADMIN_PASSWORD` | — | pgAdmin password (default: changeme) |
| `REDIS_CMD_USER` | — | Redis Commander username |
| `REDIS_CMD_PASSWORD` | — | Redis Commander password |

### Per-Service Database Passwords

Each service using the shared database should have its own password in `.env`:

```bash
NEXTCLOUD_DB_PASSWORD=changeme
GITEA_DB_PASSWORD=changeme
OUTLINE_DB_PASSWORD=changeme
AUTHENTIK_DB_PASSWORD=changeme
GRAFANA_DB_PASSWORD=changeme
VAULTWARDEN_DB_PASSWORD=changeme
BOOKSTACK_DB_PASSWORD=changeme
```

Run `./scripts/init-databases.sh` after setting these to create the databases and users.

## Service URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| pgAdmin | `https://pgadmin.<DOMAIN>` | Set by `PGADMIN_EMAIL` / `PGADMIN_PASSWORD` |
| Redis Commander | `https://redis.<DOMAIN>` | Set by `REDIS_CMD_USER` / `REDIS_CMD_PASSWORD` |

## Connecting to Databases

### PostgreSQL

```
Host: homelab-postgres
Port: 5432
Database: <service-name>
Username: <service-name>
Password: <service-db-password>
```

### Redis

```
Host: homelab-redis
Port: 6379
Password: ${REDIS_PASSWORD}
```

Redis databases are allocated per service:
- DB 0 — Authentik
- DB 1 — Outline
- DB 2 — Gitea
- DB 3 — Nextcloud
- DB 4 — Grafana sessions
- DB 5 — Vaultwarden

Connect string example: `redis://:${REDIS_PASSWORD}@homelab-redis:6379/1` (for Outline, DB 1)

### MariaDB

```
Host: homelab-mariadb
Port: 3306
Root Password: ${MARIADB_ROOT_PASSWORD}
```

## Backup

Backups are handled by `scripts/backup-databases.sh` at the repo root:

```bash
# Backup all databases
./scripts/backup-databases.sh --all

# Backup PostgreSQL only
./scripts/backup-databases.sh --postgres

# Backup to MinIO (if MinIO is deployed)
./scripts/backup-databases.sh --all --upload
```

Backups are saved to `backups/` with timestamped filenames.

## Database Initialization

The `scripts/init-databases.sh` script creates databases and users for all services:

```bash
# Idempotent — safe to run multiple times
./scripts/init-databases.sh
```

It creates:
- Database + user for each service (nextcloud, gitea, outline, authentik, grafana, vaultwarden, bookstack)
- Grants appropriate privileges

## Network Isolation

All database services are on the `databases` bridge network and are NOT exposed to the host or internet (except pgAdmin and Redis Commander which are on `proxy` via Traefik).

This means:
- Services in other stacks can reach databases via hostname: `homelab-postgres`, `homelab-redis`, `homelab-mariadb`
- Databases are not accessible from outside the Docker network

## Troubleshooting

### "Connection refused" when other stacks try to connect

Ensure both stacks are on the same Docker network. Add to the connecting stack's compose:
```yaml
networks:
  databases:
    external: true
```

### pgAdmin can't connect to PostgreSQL
pgAdmin runs on the `proxy` network AND `databases` network. It should be able to reach PostgreSQL at `homelab-postgres:5432`.

### Redis Commander shows empty data
Redis Commander uses `homelab-redis:6379` with the password `${REDIS_PASSWORD}`. Make sure `REDIS_PASSWORD` is set in `.env`.
