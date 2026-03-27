# Base Infrastructure Stack

The foundation of HomeLab Stack. Must be deployed **before any other stack**.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Traefik | 3.1 | `traefik.<DOMAIN>` | Reverse proxy + TLS termination |
| Portainer CE | 2.21 | `portainer.<DOMAIN>` | Docker management UI |
| Watchtower | latest-stable | — | Automatic container updates |
| Docker Socket Proxy | 0.2.0 | internal | Secure Docker API proxy (no public URL) |

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
    └──► *.<DOMAIN>           → Other stacks via 'proxy' network

[socket-proxy] ←── Traefik reads container labels via this secure proxy
    │
    └──► /var/run/docker.sock (restricted API — no dangerous ops)

[proxy] ← shared Docker network — all stacks attach here
```

## Security: Docker Socket Proxy

Traefik accesses the Docker API through `socket-proxy` instead of the raw socket. This
provides defense-in-depth:

- **Read-only API**: Traefik can only list containers and read metadata — it cannot
  create, destroy, or modify containers
- **No exec access**: Even if Traefik is compromised, attackers cannot use the Docker
  socket to escape to the host
- **Portainer exception**: Portainer retains direct socket access (full API) since it
  needs it for container management

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
`config/traefik/acme.json` (created automatically on first run).

### DNS Configuration

Point your domain's A record to your server IP. For subdomains used by other stacks
(e.g. `portainer.<DOMAIN>`, `traefik.<DOMAIN>`), add corresponding CNAME or A records.

### Container Update Labels

Other stacks inherit the base network automatically. To enable Traefik routing and
Watchtower updates, add these labels to your containers:

```yaml
services:
  my-service:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-service.rule=Host(`my-service.${DOMAIN}`)"
      - "traefik.http.routers.my-service.entrypoints=websecure"
      - "traefik.http.routers.my-service.tls.certresolver=letsencrypt"
      # Watchtower update scope (add to .env of the stack):
      # WATCHTOWER_LABEL_ENABLE=true
```

## Troubleshooting

### Traefik dashboard returns 404

Ensure the container has `traefik.enable=true` label and is on the `proxy` network.

### Socket proxy connection errors in Traefik logs

Verify `socket-proxy` container is running: `docker ps | grep socket-proxy`. If it's
not running, check logs with `docker logs socket-proxy`.

### Certificates not issued

Ensure port 80 is open and accessible. Let's Encrypt HTTP-01 challenge requires port 80
to be reachable from the internet.
