# Backup & DR Stack — Automated Backup + Disaster Recovery

**Bounty: $150 USDT**

Docker Compose stack for automated backups and disaster recovery, monitored via Prometheus.

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| Duplicati | `lscr.io/linuxserver/duplicati:2.1` | Web UI backup manager with dedup + encryption |
| Restic | `restic/restic:0.17` | Automated CLI backups with S3/SFTP/local support |
| Prometheus | `prom/prometheus:v2.54` | Monitoring and alerting |
| Healthcheck | `alpine:3.20` | Periodic container + backup freshness checks |

## Quick Start

```bash
# 1. Configure
cp .env.example .env
# Edit .env: set passwords, domains, backup paths

# 2. Create directories
mkdir -p scripts config

# 3. Install scripts
cp scripts/*.sh ./
chmod +x backup.sh healthcheck.sh

# 4. Start the stack
docker compose up -d
```

## Backup Strategy

| Method | Schedule | Retention | Scope |
|--------|----------|-----------|-------|
| Restic (auto) | Every 24h | 7 daily, 4 weekly, 12 monthly | `/data` directory |
| Duplicati (manual) | On-demand via UI | Configurable via web UI | Full file system |

## Restic Features

- **Encrypted** — AES-256 via restic
- **Deduplicated** — block-level dedup across all snapshots
- **Pruned** — auto-forget old snapshots
- **Verified** — integrity check every Sunday
- **S3-compatible** — remote backup via S3/MinIO

## Duplicati Features

- Web UI at `https://backups.example.com`
- AES-256 encryption with configurable key
- Incremental backups with block-level dedup
- Supports: Local, FTP, SFTP, WebDAV, S3, Azure, Google Drive, Dropbox

## Monitoring

- Prometheus at `https://monitor.example.com`
- Container health checks every hour
- Backup freshness alerts (>48h since last backup)
- Prometheus scraping for Docker host metrics

## Disaster Recovery

```bash
# List snapshots
docker compose exec restic restic snapshots

# Restore latest snapshot
docker compose exec restic restic restore latest --target /restore

# Restore specific snapshot
docker compose exec restic restic restore SNAPSHOT_ID --target /restore
```
