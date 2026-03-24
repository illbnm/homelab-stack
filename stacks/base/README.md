# Base Infrastructure Stack

The foundation of HomeLab Stack. Must be deployed **before any other stack**.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Traefik | 3.1.6 | `traefik.<DOMAIN>` | Reverse proxy + TLS termination |
| Portainer CE | 2.21.3 | `portainer.<DOMAIN>` | Docker management UI |
| Watchtower | 1.7.1 | — | Automatic container updates (3:00 AM daily) |
| Socket Proxy | 0.2.0 | — | Secure Docker socket isolation |

## Architecture

```
Internet
    │
    ▼
[Traefik :443]
    │  TLS termination (Let's Encrypt)
    │  ForwardAuth → Authentik (optional)
    │
    ├──► portainer.<DOMAIN>  → Portainer
    ├──► traefik.<DOMAIN>    → Traefik Dashboard
    └──► *..<DOMAIN>         → Other stacks via 'proxy' network

[Socket Proxy] ← Secure Docker socket access for Traefik & Watchtower
[proxy] ← shared Docker network — all stacks attach here
```

## Security Features

### Docker Socket Isolation

Traefik and Watchtower access Docker API through **Socket Proxy** instead of mounting
`/var/run/docker.sock` directly. Socket Proxy limits API access to read-only operations:

- `CONTAINERS=1` — List and inspect containers
- `SERVICES=1` — List services
- `TASKS=1` — List tasks
- `NETWORKS=1` — List networks
- `INFO=1`, `PING=1`, `VERSION=1` — System info
- `EVENTS=1` — Subscribe to events

Portainer requires full Docker socket access for management operations.

## Prerequisites

- Docker >= 24.0 with Compose v2 plugin
- Ports 80 and 443 open on your firewall
- A domain pointing to your server's IP (A record)
- `./scripts/setup-env.sh` completed (creates `.env` and `acme.json`)

## Quick Start

```bash
# From repo root — recommended (runs check-deps + setup-env first)
./install.sh

# Or manually:
cd stacks/base
ln -sf ../../.env .env       # share root .env
docker compose up -d
```

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain, e.g. `home.example.com` |
| `ACME_EMAIL` | ✅ | Email for Let's Encrypt notifications |
| `TRAEFIK_DASHBOARD_USER` | ✅ | Dashboard login username |
| `TRAEFIK_DASHBOARD_PASSWORD_HASH` | ✅ | Bcrypt hash — see below |
| `TZ` | ✅ | Timezone, e.g. `Asia/Shanghai` |
| `CN_MODE` | — | `true` to use CN Docker mirrors |

### Generate Dashboard Password Hash

```bash
# Install htpasswd (Debian/Ubuntu)
sudo apt-get install -y apache2-utils

# Generate hash (replace 'yourpassword')
htpasswd -nbB admin 'yourpassword' | sed -e 's/\$$/\$\$\$/g'

# Paste output into .env as TRAEFIK_DASHBOARD_PASSWORD_HASH
```

### TLS Certificates

Traefik uses Let's Encrypt HTTP-01 challenge by default. Certificates are stored in