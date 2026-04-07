# Base Infrastructure Stack

The foundation of HomeLab Stack. Must be deployed **before any other stack**.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Socket Proxy | 0.2.0 | — | Secure Docker socket access |
| Traefik | 3.1.6 | `traefik.<DOMAIN>` | Reverse proxy + TLS termination |
| Portainer CE | 2.21.4 | `portainer.<DOMAIN>` | Docker management UI |
| Watchtower | 1.7.1 | — | Automatic container updates |

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

[proxy] ← shared Docker network — all stacks attach here
```

### Security: Socket Proxy

All services that need Docker access (Traefik, Portainer, Watchtower) connect through the **Socket Proxy** instead of directly mounting the Docker socket. This provides:

- **Least privilege**: Each service only gets the Docker API permissions it needs
- **Read-only access**: Prevents accidental or malicious container modifications
- **Auditability**: All Docker API calls go through a single controlled point
- **Network isolation**: Docker socket is not exposed to container networks

The Socket Proxy is configured to allow only specific read-only Docker operations:

- List and inspect containers, services, networks, and images
- Get Docker system information
- All write operations (POST, DELETE, PUT) are disabled

This significantly reduces the attack surface compared to giving containers full Docker socket access.

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