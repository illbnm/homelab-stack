# Disaster Recovery

## Recovery Strategy

This project follows a 3-2-1 backup strategy:

- 3 copies of important data
- 2 different storage types
- 1 off-site copy

## Backup

Run a complete backup:

```bash
./scripts/backup.sh --target all