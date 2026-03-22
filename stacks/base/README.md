# Base Infrastructure Stack

The foundation of HomeLab Stack. Must be deployed **before any other stack**.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Traefik | 3.1 | `traefik.<DOMAIN>` | Reverse proxy + TLS termination |
| Portainer CE | 2.21 | `portainer.<DOMAIN>` | Docker management UI |
| Watchtower | 1.7.1 | — | Automatic container updates |
| Docker Socket Proxy | 0.2.0 | — | Secure read-only Docker API |

## Architecture

```
Internet
    │
    ▼
[Traefik :443]
    │  TLS termination (Let's Encrypt)
    │  Docker provider via socket-proxy (read-only)
    │
    ├──► portainer.<DOMAIN>  → Portainer
    ├──► traefik.<DOMAIN>    → Traefik Dashboard
    └──► *.<DOMAIN>          → Other stacks via 'proxy' network

[docker-socket-proxy]  ← secure read-only Docker API (port 2375)
[proxy]               ← shared Docker network — all stacks attach here
```

## Prerequisites

- Docker >= 24.0 with Compose v2 plugin
- Ports 80 and 443 open on your firewall
- A domain pointing to your server's IP (A record for `*.<DOMAIN>`)
- `./scripts/setup-env.sh` completed (creates `.env` and `acme.json`)

## Quick Start

```bash
# From repo root — recommended (runs check-deps + setup-env first)
./install.sh

# Or manually:
cd stacks/base
ln -sf ../../.env .env       # share root .env
docker network create proxy  # one-time setup
touch ../../config/traefik/acme.json && chmod 600 ../../config/traefik/acme.json
docker compose up -d
```

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain, e.g. `home.example.com` |
| `ACME_EMAIL` | ✅ | Email for Let's Encrypt notifications |
| `TRAEFIK_AUTH` | ✅ | htpasswd string (see below) |
| `TZ` | ✅ | Timezone, e.g. `Asia/Shanghai` |
| `NTFY_URL` | — | ntfy topic URL for Watchtower alerts |
| `NTFY_TOKEN` | — | ntfy auth token (if required) |
| `GOTIFY_URL` | — | Gotify URL for Watchtower alerts |
| `GOTIFY_TOKEN` | — | Gotify token |
| `CN_MODE` | — | `true` to use CN Docker mirrors |

### Generate Dashboard Auth (htpasswd)

```bash
# Install htpasswd (Debian/Ubuntu)
sudo apt-get install -y apache2-utils

# Generate auth string (replace 'yourpassword')
htpasswd -nb admin 'yourpassword'

# Output example: admin:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/
# Paste into .env as TRAEFIK_AUTH
```

### DNS Configuration

Create the following DNS A records pointing to your server IP:

| Record | Type | Target |
|--------|------|--------|
| `*.example.com` | A | `<YOUR_SERVER_IP>` |

Wildcard is required for automatic per-service subdomains.

### TLS Certificates

Traefik uses Let's Encrypt HTTP-01 challenge by default. Certificates are stored in `config/traefik/acme.json` (created automatically on first request).

For wildcard certificates, switch to DNS challenge in `config/traefik/traefik.yml` using the `letsencrypt-dns` resolver.

### Watchtower — Selective Updates

Watchtower **only updates containers** that have this label:

```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=true"
```

Add this label to any container you want auto-updated. The base stack's own containers (Traefik, Portainer, etc.) are **not** auto-updated by default.

### Portainer — Direct Socket Note

Portainer requires a **direct** Docker socket (not via the proxy) because it performs write operations. The socket is mounted directly with `:ro` only for Traefik and read-only for Portainer's socket path is intentional — Portainer handles write operations through its own internal API.

## Security Notes

- Traefik accesses Docker via `docker-socket-proxy` (read-only API on port 2375)
- The proxy port is bound to `127.0.0.1:2375` — not exposed externally
- ACME.json must have permissions `600`: `chmod 600 config/traefik/acme.json`

## Troubleshooting

**Traefik dashboard returns 404:**
- Ensure `traefik.enable=true` label is set on the container
- Check `config/traefik/dynamic/middlewares.yml` contains the auth middleware

**Let's Encrypt fails:**
- Verify port 80 is open and not in use
- Ensure DNS A record is propagated: `dig traefik.yourdomain.com`
- Check logs: `docker logs traefik`

**Watchtower not updating containers:**
- Ensure label `com.centurylinklabs.watchtower.enable=true` is set
- Check Watchtower logs: `docker logs watchtower`
