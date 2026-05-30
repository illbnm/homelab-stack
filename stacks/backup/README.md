# Backup Stack — 3-2-1 Backup Strategy

## Services

- **Duplicati** — Encrypted cloud backups with web UI
- **Restic REST Server** — Local backup repository

## Configuration

Edit `.env` to configure backup target (local, s3, b2, sftp).

## Usage

Start the stack:
```bash
docker compose up -d
```

Access Duplicati: https://backup.your-domain.com

## Restore

See `docs/disaster-recovery.md` for full recovery procedures.
