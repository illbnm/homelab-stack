# Backup & DR Stack — Restic + Duplicati

Automated encrypted backups with incremental snapshots and disaster recovery.

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| **Duplicati** | `https://backup.${DOMAIN}` | Web UI for backup scheduling, cloud/NAS targets |
| **Restic** | CLI only | Incremental encrypted snapshots, pruning, integrity checks |

## Quick Start

```bash
cp .env.example .env
# Set RESTIC_PASSWORD, DUPLICATI_ENCRYPTION_KEY, paths

# Initialize Restic repository (first time only)
docker compose run --rm restic init

# Run first backup
docker compose up -d
bash backup.sh daily
```

## Automation

The `backup.sh` script supports three modes:

| Mode | What It Does |
|------|-------------|
| `daily` | Backup Docker volumes + data directories (incremental) |
| `weekly` | Daily + snapshot rotation (keep 7 daily, 4 weekly, 6 monthly) |
| `full` | Weekly + integrity check via `restic check` |

## Restore

```bash
# List snapshots
docker compose run --rm restic snapshots

# Restore latest to /tmp/restore
docker compose run --rm -v /tmp/restore:/restore restic restore latest --target /restore
```

## Encryption

Both Restic and Duplicati use AES-256 encryption. Generate keys:

```bash
openssl rand -base64 32  # Duplicati encryption key
openssl rand -hex 16      # Restic password
```
