# Disaster Recovery Runbook (3-2-1 Strategy)

## 1. 3-2-1 Backup Architecture

- **3 Copies of Data**: Live production volumes (`/data`), local Restic repository (`/data/backups/restic-repo`), and encrypted off-site cloud archive.
- **2 Storage Media**: Local NVMe/ZFS pool + object storage (`MinIO S3` / NAS).
- **1 Off-Site Replica**: Backblaze B2 (`b2`), Cloudflare R2 (`r2`), or remote SFTP (`sftp`) scheduled daily at `02:00 AM` (`0 2 * * * /opt/homelab/scripts/backup.sh --target all`).

## 2. Recovery Sequence & RTO / RPO Targets

| Phase | Stack | Recovery Order | Target RTO | Target RPO |
|---|---|---|---|---|
| 1 | `Base` (Traefik + Portainer + Watchtower) | 1st | 10 min | 24h |
| 2 | `Databases` (PostgreSQL + Redis + MariaDB) | 2nd | 15 min | 24h |
| 3 | `SSO` (Authentik Server + Worker) | 3rd | 15 min | 24h |
| 4 | `Storage` (Nextcloud + MinIO + FileBrowser + Syncthing) | 4th | 25 min | 24h |
| 5 | `Productivity / Media / AI / Observability` | 5th | 30 min | 24h |

## 3. Bare-Metal Step-by-Step Recovery Procedure

1. Provision fresh Ubuntu 22.04/24.04 host and run `./install.sh --cn`.
2. Verify snapshot integrity: `./scripts/backup.sh --verify`.
3. Restore snapshot: `./scripts/backup.sh --restore latest --target all`.
4. Start stacks in order (`base` -> `databases` -> `sso` -> `storage` -> `observability`) and verify with `./scripts/wait-healthy.sh --stack <name> --timeout 300`.

## 4. Post-Restore Verification Checklist

- [ ] `docker compose ps` shows `healthy` on all restored services
- [ ] PostgreSQL databases (`gitea`, `nextcloud`, `outline`, `authentik`) pass checksum verification
- [ ] Authentik OIDC login succeeds across Grafana, Gitea, Nextcloud, and Outline
