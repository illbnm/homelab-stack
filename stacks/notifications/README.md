# Notifications Stack

Push notifications via **ntfy** and **Gotify**, proxied by Traefik with TLS.

## Services

| Service | Access URL | Description |
|---------|------------|-------------|
| ntfy   | `https://ntfy.<DOMAIN>` | Topic-based pub/sub, WebSocket support |
| Gotify | `https://gotify.<DOMAIN>` | Priority-based push API |

Both services share the `proxy` Docker network and use `tls=true` (TLS configured separately via Traefik).

## Setup

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env and set DOMAIN and GOTIFY_PASSWORD

# 2. Start
docker compose up -d

# 3. Create an ntfy account
open https://ntfy.<DOMAIN>/settings  # go to Access Tokens tab
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | — | Your domain (e.g. `homelab.local`) |
| `NTFY_AUTH_DEFAULT_ACCESS` | `deny-all` | `open-access` to allow anonymous use |
| `GOTIFY_PASSWORD` | — | Admin password for Gotify |

## Notification Script

`scripts/notify.sh` sends to either backend:

```bash
# ntfy — topics are public unless NTFY_AUTH_DEFAULT_ACCESS=deny-all
./scripts/notify.sh ntfy alerts "Disk full" "sda1 at 95%" warning,floppy_disk
./scripts/notify.sh ntfy alerts "Deploy done" "Server restarted at $(date)"

# Gotify — requires app token from Gotify UI
./scripts/notify.sh gotify ABPwGt2...8xX "Deploy done" "Server restarted" 5
```

Priority levels (Gotify): 1=min, 3=normal, 5=high, 7=max, 9=emergency.

## First-Run: Getting Tokens

### ntfy Access Token

1. Open `https://ntfy.<DOMAIN>` → **Settings** → **Access Tokens** → **Create access token**
2. Name it (e.g. `homelab-alerts`) and click **CREATE**
3. Use the token in your scripts or the web UI for authenticated posting

### Gotify App Token

1. Open `https://gotify.<DOMAIN>` — login with `admin` / `$GOTIFY_PASSWORD`
2. Click **APP** → **Create application** → name it → **CREATE**
3. Copy the app token (shown once)

## Healthchecks

```bash
# ntfy
curl -s -o /dev/null -w "%{http_code}" https://ntfy.<DOMAIN>/v1/health
# Expected: 200

# Gotify
curl -s https://gotify.<DOMAIN>/health
# Expected: {"app":"gotify", "version": "2.5.0", ...}
```

## Upgrading

```bash
docker compose pull && docker compose up -d
```

## Backing Up Data

```bash
# Backup ntfy (auth + cache)
docker run --rm \
  -v $(pwd)/ntfy-auth:/var/lib/ntfy \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/ntfy-$(date +%Y%m%d).tar.gz -C /var/lib/ntfy ntfy

# Backup Gotify
docker run --rm \
  -v $(pwd)/gotify-data:/var/lib/gotify \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/gotify-$(date +%Y%m%d).tar.gz -C /var/lib/gotify gotify
```