# Base Infrastructure Stack

The foundation of HomeLab Stack. Must be deployed **before any other stack**.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Traefik | 3.1.6 | `traefik.<DOMAIN>` | Reverse proxy + TLS termination |
| Portainer CE | 2.21.4 | `portainer.<DOMAIN>` | Docker management UI |
| Watchtower | 1.7.1 | — | Automatic container updates |
| Socket Proxy | 0.2.0 | — | Secure Docker API gateway |

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

[Socket Proxy] ← Traefik, Portainer, Watchtower all connect here
                     ↓ (filtered API calls only)
                  [/var/run/docker.sock]
                     ↓
[proxy] ← shared Docker network — all stacks attach here
```

### Security: Docker Socket Proxy

All services access the Docker API through **docker-socket-proxy** instead of directly mounting the socket. This limits exposed endpoints to only what's needed:

- ✅ `CONTAINERS`, `IMAGES`, `NETWORKS`, `VOLUMES`, `EVENTS` — read + limited write
- ❌ `EXEC`, `BUILD`, `SWARM`, `SYSTEM` — completely blocked

## Prerequisites

- Docker >= 24.0 with Compose v2 plugin
- Ports 80 and 443 open on your firewall
- A domain with A record pointing to your server IP

## Quick Start

```bash
# From repo root (recommended):
./install.sh

# Or manually:
cd stacks/base

# 1. Create environment file
cp .env.example .env
# Edit .env: set DOMAIN, ACME_EMAIL, TRAEFIK_DASHBOARD_PASS

# 2. Create proxy network (if not exists)
docker network create proxy

# 3. Generate htpasswd for Traefik dashboard
# Option A: manual
htpasswd -nb admin YOUR_PASSWORD > ../../config/traefik/dynamic/.htpasswd
# Option B: using the setup script
bash ../../scripts/setup-env.sh

# 4. Create ACME storage file
touch ../../config/traefik/acme.json
chmod 600 ../../config/traefik/acme.json

# 5. Start all services
docker compose up -d

# 6. Verify
docker compose ps
curl -k https://traefik.$DOMAIN  # Should show dashboard (login required)
```

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | ✅ | — | Base domain, e.g. `home.example.com` |
| `ACME_EMAIL` | ✅ | — | Email for Let's Encrypt notifications |
| `ACME_CHALLENGE` | — | `http` | `http` or `dns` (wildcard certs) |
| `TRAEFIK_DASHBOARD_USER` | ✅ | `admin` | Dashboard login username |
| `TRAEFIK_DASHBOARD_PASS` | ✅ | — | Dashboard password |
| `WATCHTOWER_SCHEDULE` | — | `0 0 4 * * *` | Cron for update checks |
| `TZ` | — | `Asia/Shanghai` | Timezone |
| `CN_MODE` | — | `false` | Use CN Docker mirrors |

### DNS Configuration

1. Create an A record: `*.<DOMAIN>` → your server IP (or `@` + `*`)
2. For wildcard certs (DNS challenge): add appropriate TXT records per your DNS provider

### Certificate Configuration

**HTTP Challenge (default):**
- Works out of the box with port 80 open
- No DNS provider config needed

**DNS Challenge (for wildcard certs):**
1. Set `ACME_CHALLENGE=dns` in `.env`
2. Set `ACME_DNS_PROVIDER` and `ACME_DNS_TOKEN`
3. Traefik will auto-request wildcard cert `*.DOMAIN`

## Verification Checklist

- [ ] `docker compose up -d` starts all 4 containers
- [ ] All containers show "healthy" status: `docker compose ps`
- [ ] `http://<IP>:80` auto-redirects to `https://...`
- [ ] `https://traefik.<DOMAIN>` shows dashboard (requires login)
- [ ] `https://portainer.<DOMAIN>` shows Portainer UI
- [ ] Other stack containers can be discovered via `proxy` network
- [ ] No service directly mounts `/var/run/docker.sock` (all go through socket-proxy)

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Traefik dashboard not loading | Check `.htpasswd` file exists and is valid |
| ACME certificate errors | Verify port 80/443 open, DNS record correct |
| Portainer can't see containers | Ensure socket-proxy is healthy: `docker logs socket-proxy` |
| Watchtower not updating | Check label `com.centurylinklabs.watchtower.enable=true` on target containers |

## File Structure

```
stacks/base/
├── docker-compose.yml        # Main compose file
├── docker-compose.local.yml  # Local override (no HTTPS, for dev)
├── .env.example              # Environment variables template
└── README.md                 # This file

config/traefik/
├── traefik.yml               # Static configuration
├── traefik.local.yml         # Local static config (no ACME)
├── acme.json                 # Let's Encrypt certificate storage (auto-generated)
└── dynamic/
    ├── .htpasswd             # Basic auth for dashboard (auto-generated)
    ├── authentik.yml         # Authentik SSO middleware
    ├── middlewares.yml       # Shared middlewares (security, rate-limit, etc.)
    └── tls.yml               # TLS options
```
