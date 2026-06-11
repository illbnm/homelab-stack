# Backup & Disaster Recovery Stack
3-2-1 backup strategy with Duplicati + Restic REST Server.
## Deployment
1. Start: `docker compose up -d`
2. Schedule backup via cron: `0 2 * * * /path/to/backup.sh --target all`
3. Restore: `backup.sh --restore <backup-id>`
