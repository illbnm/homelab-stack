# Productivity Stack

Self-hosted productivity tools: Git hosting and password management.

## Services

| Service | URL | Port |
|---------|-----|------|
| Gitea | `https://git.${DOMAIN}` | 3000 (HTTP), 2222 (SSH) |
| Vaultwarden | `https://vault.${DOMAIN}` | 80 |

## Quick Start

```bash
cp .env.example .env
nano .env   # Set DOMAIN and VAULTWARDEN_ADMIN_TOKEN

# Requires Traefik proxy network (from base stack):
docker network create proxy  # skip if already exists

docker compose up -d
```

## First-Time Setup

### Gitea
1. Navigate to `https://git.${DOMAIN}`
2. First user to register becomes admin (then disable registration via env)
3. SSH cloning: `git clone git@git.${DOMAIN}:2222/user/repo.git`

### Vaultwarden
1. Navigate to `https://vault.${DOMAIN}`
2. Create your account (first signup)
3. Set `VAULTWARDEN_SIGNUPS=false` to lock registrations
4. Admin panel: `https://vault.${DOMAIN}/admin` (use `VAULTWARDEN_ADMIN_TOKEN`)
5. Use any Bitwarden-compatible client (browser extension, mobile app, desktop)

## Dependencies

- Traefik reverse proxy (base stack) — for HTTPS and routing
- Ports 80/443 must be open on the host for Let's Encrypt
- Port 2222 open for Gitea SSH access (optional)

## Data Persistence

All data is stored in named Docker volumes:
- `gitea_data` — repositories, users, config
- `vaultwarden_data` — vault database, attachments

## Backup

```bash
# Gitea
docker exec gitea gitea dump -c /data/gitea/conf/app.ini

# Vaultwarden
docker stop vaultwarden
tar -czf vaultwarden-backup-$(date +%Y%m%d).tar.gz /var/lib/docker/volumes/productivity_vaultwarden_data/
docker start vaultwarden
```
