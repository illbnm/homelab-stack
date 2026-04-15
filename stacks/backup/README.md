# Backup & Disaster Recovery Stack

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| Duplicati | `lscr.io/linuxserver/duplicati:2.0.8` | Encrypted cloud backup (S3, B2, SFTP) |
| Restic REST Server | `restic/rest-server:0.12.1` | Local deduplicated backup server |

## Quick Start

```bash
cp .env.example .env
# Edit .env with your values
docker compose up -d
```

## Architecture

```
┌──────────────┐     ┌─────────────────┐     ┌──────────────┐
│  Source Data  │────▶│    Restic        │────▶│  Local Disk  │
│  /data        │     │  (dedup + incr)  │     │  /backups    │
└──────────────┘     └─────────────────┘     └──────────────┘
       │
       ▼
┌─────────────────┐     ┌──────────────┐
│    Duplicati     │────▶│  Cloud (S3,  │
│  (encrypted)     │     │  B2, SFTP)   │
└─────────────────┘     └──────────────┘
```

## Backup Script

The `scripts/backup.sh` script provides a unified interface:

```bash
# Full backup
./scripts/backup.sh

# Restic only
./scripts/backup.sh --target restic

# Dry run
./scripts/backup.sh --dry-run

# List snapshots
./scripts/backup.sh --list

# Verify integrity
./scripts/backup.sh --verify

# Restore
./scripts/backup.sh --restore restic <SNAPSHOT_ID>

# Cleanup old backups
./scripts/backup.sh --cleanup
```

## Endpoints

| Service | URL |
|---------|-----|
| Duplicati | `https://duplicati.${DOMAIN}` |
| Restic REST | `http://restic:8000` (internal) |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | Yes | Your domain (e.g., `homelab.local`) |
| `TZ` | No | Timezone (default: `Asia/Shanghai`) |
| `STORAGE_PATH` | No | Source data path (default: `/data`) |
| `RESTIC_PASSWORD` | Yes | Restic repository encryption password |
| `DUPLICATI_PASSPHRASE` | Yes | Duplicati backup encryption passphrase |

## Acceptance Criteria

- [x] Both services start with `docker compose up -d`
- [x] Health checks configured (30s interval)
- [x] Duplicati accessible via Traefik at `duplicati.${DOMAIN}`
- [x] Restic REST server for local deduplicated backups
- [x] Unified backup script with dry-run, restore, verify, cleanup
- [x] Disaster recovery documentation
- [x] Traefik integration via `proxy` network
- [x] Complete `.env.example` with all variables documented

## Recovery

See [docs/disaster-recovery.md](../../docs/disaster-recovery.md) for full recovery procedures.
