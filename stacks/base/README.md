# Base Infrastructure Stack

The foundation of HomeLab Stack. Must be deployed **before any other stack**.

## What's Included

| Service | Image | URL | Purpose |
|---------|-------|-----|---------|
| Traefik | `traefik:v3.1.6` | `traefik.<DOMAIN>` | Reverse proxy + auto HTTPS |
| Portainer CE | `portainer/portainer-ce:2.21.3` | `portainer.<DOMAIN>` | Docker management UI |
| Watchtower | `containrrr/watchtower:1.7.1` | — | Automatic container updates (3 AM daily) |
| Socket Proxy | `tecnativa/docker-socket-proxy:0.2.0` | — | Secure Docker socket isolation |

## Architecture

```
Internet
    │
    ▼
[Traefik :80/:443]
    │  HTTP → HTTPS redirect (automatic)
    │  TLS termination (Let's Encrypt)
    │  ForwardAuth → Authentik (optional)
    │
    ├──► traefik.<DOMAIN>   → Traefik Dashboard (BasicAuth protected)
    ├──► portainer.<DOMAIN> → Portainer CE
    └──► *.<DOMAIN>         → Other stacks via 'proxy' network

[socket-proxy] ← isolates Docker socket — Traefik & Portainer connect here
[proxy]        ← shared Docker network — all stacks attach here
```

## Prerequisites

- Docker >= 24.0 with Compose v2 plugin
- Ports 80 and 443 open on your firewall
- A domain with wildcard DNS pointing to your server (`*.home.example.com → your-server-IP`)
- `./scripts/check-deps.sh` passed

## Quick Start

```bash
# From repo root (recommended — runs all checks + env setup)
./install.sh

# Or manually:
docker network create proxy
cd stacks/base
cp .env.example .env
nano .env                        # Fill in DOMAIN, ACME_EMAIL, etc.
touch ../../config/traefik/acme.json && chmod 600 ../../config/traefik/acme.json
docker compose up -d
```

## DNS Configuration

You need **either**:

**Option A: Wildcard DNS (recommended)**
```
*.home.example.com  →  A  →  YOUR_SERVER_IP
```
This covers all subdomains automatically.

**Option B: Individual records**
```
traefik.home.example.com   →  A  →  YOUR_SERVER_IP
portainer.home.example.com →  A  →  YOUR_SERVER_IP
grafana.home.example.com   →  A  →  YOUR_SERVER_IP
...
```

## TLS Certificates

Traefik obtains certificates automatically via Let's Encrypt.

**HTTP-01 Challenge** (default): Works with port 80 open. One cert per subdomain.

**DNS-01 Challenge** (wildcard): Edit `config/traefik/traefik.yml` to use `letsencrypt-dns` resolver and set your DNS provider API credentials. Supports `*.domain.com` wildcard certs.

Certificates are stored in `config/traefik/acme.json` (must be `chmod 600`).

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | Yes | Base domain, e.g. `home.example.com` |
| `ACME_EMAIL` | Yes | Email for Let's Encrypt notifications |
| `TRAEFIK_DASHBOARD_USER` | Yes | Dashboard login username |
| `TRAEFIK_DASHBOARD_PASSWORD_HASH` | Yes | Bcrypt hash (see below) |
| `TZ` | Yes | Timezone, e.g. `Asia/Shanghai` |
| `WATCHTOWER_NOTIFICATION_URL` | No | ntfy URL for update notifications |
| `AUTHENTIK_DOMAIN` | No | SSO domain (if using Authentik) |

### Generate Dashboard Password Hash

```bash
# Install htpasswd (Debian/Ubuntu)
sudo apt-get install -y apache2-utils

# Generate hash (replace 'yourpassword')
htpasswd -nbB admin 'yourpassword' | sed -e 's/\$/\$\$/g'

# Paste the output into .env as TRAEFIK_DASHBOARD_PASSWORD_HASH
```

## Security: Docker Socket Proxy

This stack uses `tecnativa/docker-socket-proxy` to isolate the Docker socket.
No container mounts `/var/run/docker.sock` directly. Traefik and Portainer
connect to the proxy via `tcp://socket-proxy:2375` on an internal-only network.

## Verify Deployment

```bash
# All 4 containers should be running and healthy
docker compose ps

# HTTP → HTTPS redirect working
curl -I http://YOUR_SERVER_IP
# Expected: 301/302 redirect to https://

# Dashboard accessible (replace domain)
curl -k https://traefik.example.com/api/version
# Expected: 200 with Traefik version JSON

# Portainer accessible
curl -k https://portainer.example.com/api/status
# Expected: 200
```
