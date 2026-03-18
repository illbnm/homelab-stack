## Databases Stack Implementation

Implements **Bounty #11: Database Layer ($130 USDT)**

### Services (5 containers)

| Service | Image | Network | Description |
|---------|-------|---------|-------------|
| PostgreSQL | postgres:16.4-alpine | databases | Multi-tenant relational DB |
| Redis | redis:7.4.0-alpine | databases | Cache & message queue |
| MariaDB | mariadb:11.5.2 | databases | MySQL-compatible DB |
| pgAdmin | dpage/pgadmin4:8.11 | databases + proxy | PostgreSQL web UI |
| Redis Commander | rediscommander/redis-commander | databases + proxy | Redis web UI |

### Key Changes

- **Idempotent init script** — `create_db()` helper uses `IF NOT EXISTS` checks, safe to re-run
- **7 pre-configured databases**: nextcloud, gitea, outline, authentik, grafana, vaultwarden, bookstack
- **pgAdmin + Redis Commander** with Traefik routing for web management
- **Network isolation**: DB containers on `databases` network only, admin UIs bridged to `proxy`
- **Backup script** (`scripts/backup-databases.sh`): pg_dumpall + redis BGSAVE + mysqldump, compressed tar.gz, 7-day retention, optional MinIO upload
- **Redis database allocation** documented (DB 0-4 per service)
- **README.md**: connection strings, restore procedures, cron scheduling, troubleshooting

### Acceptance Criteria

- [x] init-databases.sh creates all databases and users
- [x] init-databases.sh is idempotent (re-run without errors)
- [x] pgAdmin accessible via Traefik and connects to PostgreSQL
- [x] Other stacks can connect via `databases` network hostname
- [x] Database containers NOT exposed to host ports
- [x] backup-databases.sh generates valid .tar.gz backups
- [x] README includes connection string examples for all DB types

Generated/reviewed with: claude-opus-4-6
