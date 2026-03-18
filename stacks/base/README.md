# Base Infrastructure Stack

The foundation of HomeLab Stack. Must be deployed **before any other stack**.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Docker Socket Proxy | 0.2.0 | — | Secure Docker API gateway |
| Traefik | 3.1.6 | `traefik.<DOMAIN>` | Reverse proxy + TLS termination |
| Portainer CE | 2.21.4 | `portainer.<DOMAIN>` | Docker management UI |
| Watchtower | 1.7.1 | — | Automatic container updates (daily 3 AM) |

## Architecture

```
Internet
    │
    ▼
[Traefik :80/:443]
    │  HTTP→HTTPS redirect (port 80)
    │  TLS termination via Let's Encrypt (port 443)
    │  ForwardAuth → Authentik (optional, via SSO stack)
    │
    ├──► traefik.<DOMAIN>    → Dashboard (BasicAuth protected)
    ├──► portainer.<DOMAIN>  → Portainer CE
    └──► *.<DOMAIN>          → Other stacks via 'proxy' network

[socket-proxy] ← internal network (no external access)
    │
    └──► docker-socket-proxy:2375 → Docker API (read-only, filtered)
            │
            ├── Traefik (container discovery)
            ├── Portainer (management)
            └── Watchtower (update checks)

[proxy] ← shared external Docker network — all stacks attach here
```

### Security: Docker Socket Proxy

> **No container directly mounts `/var/run/docker.sock`.**

All Docker API access goes through `docker-socket-proxy` (tecnativa/docker-socket-proxy):
- Runs on an **internal network** (no external access)
- Read-only Docker socket mount
- API filtering: only allowed endpoints are proxied
- Container is `read_only` with tmpfs for runtime files

| API | Allowed | Consumer |
|-----|---------|----------|
| Containers | ✅ | Traefik, Portainer, Watchtower |
| Networks | ✅ | Traefik |
| Services/Tasks | ✅ | Traefik |
| Images/Volumes | ✅ | Portainer |
| Events | ✅ | Portainer, Watchtower |
| Exec | ✅ | Portainer |
| Info/Version | ✅ | All |
| Secrets | ❌ | — |
| Swarm | ❌ | — |
| Build/Commit | ❌ | — |
| Auth | ❌ | — |

## Prerequisites

- Docker ≥ 24.0 with Compose v2 plugin
- Ports **80** and **443** open on your firewall
- A domain pointing to your server's IP (DNS A record)

## Quick Start

```bash
# 1. Clone and navigate
cd homelab-stack

# 2. Create environment
cp stacks/base/.env.example .env
# Edit .env — set DOMAIN, ACME_EMAIL, and generate TRAEFIK_DASHBOARD_PASSWORD_HASH

# 3. Create shared network
docker network create proxy

# 4. Prepare ACME certificate storage
touch config/traefik/acme.json && chmod 600 config/traefik/acme.json

# 5. Deploy
docker compose -f stacks/base/docker-compose.yml up -d

# 6. Verify
docker compose -f stacks/base/docker-compose.yml ps
```

Or use the automated installer:

```bash
./install.sh
```

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | ✅ | — | Base domain, e.g. `home.example.com` |
| `ACME_EMAIL` | ✅ | — | Email for Let's Encrypt notifications |
| `TRAEFIK_DASHBOARD_USER` | ✅ | `admin` | Dashboard login username |
| `TRAEFIK_DASHBOARD_PASSWORD_HASH` | ✅ | — | Bcrypt hash (see below) |
| `TZ` | ✅ | `Asia/Shanghai` | Timezone |
| `WATCHTOWER_SCHEDULE` | — | `0 0 3 * * *` | Update check cron (default: 3 AM daily) |
| `WATCHTOWER_NOTIFICATION_URL` | — | — | Shoutrrr URL for update notifications |
| `CN_MODE` | — | `false` | Use CN Docker registry mirrors |

### Generate Dashboard Password Hash

```bash
# Install htpasswd (Ubuntu/Debian)
sudo apt-get install -y apache2-utils

# Generate hash (replace 'yourpassword')
htpasswd -nbB admin 'yourpassword' | sed -e 's/\$/\$\$/g'

# Paste output into .env as TRAEFIK_DASHBOARD_PASSWORD_HASH
```

### DNS Configuration

Point these records to your server's public IP:

| Record Type | Name | Value |
|-------------|------|-------|
| A | `DOMAIN` | `YOUR_SERVER_IP` |
| A (or CNAME) | `*.DOMAIN` | `YOUR_SERVER_IP` (or `DOMAIN`) |

**Example** for `home.example.com`:
```
A     home.example.com       → 203.0.113.42
CNAME *.home.example.com     → home.example.com
```

> **Tip:** For local-only access, add entries to `/etc/hosts` or use a local DNS server (see Network Stack with AdGuard Home).

### TLS Certificates (Let's Encrypt)

Traefik uses **HTTP-01 challenge** by default:
- Requires port 80 accessible from the internet
- Certificates stored in `config/traefik/acme.json`
- Auto-renewed before expiry

#### DNS Challenge (Alternative)

For environments where port 80 is not accessible (or for wildcard certs), edit `config/traefik/traefik.yml`:

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@example.com
      storage: /acme.json
      dnsChallenge:
        provider: cloudflare  # or: route53, digitalocean, etc.
        delayBeforeCheck: 30
```

Add provider credentials to your `.env`:
```bash
CF_API_EMAIL=your@email.com
CF_DNS_API_TOKEN=your-cloudflare-api-token
```

See [Traefik DNS Providers](https://doc.traefik.io/traefik/https/acme/#providers) for full list.

### Traefik Static Configuration

The static config is at `config/traefik/traefik.yml`:
- Entry points: `web` (80), `websecure` (443)
- HTTP→HTTPS redirect enabled
- Docker provider via socket proxy (`tcp://docker-socket-proxy:2375`)
- Let's Encrypt ACME configured
- Access logging enabled

### Traefik Dynamic Configuration

Dynamic files in `config/traefik/dynamic/`:

| File | Purpose |
|------|---------|
| `tls.yml` | TLS version and cipher suite configuration |
| `middlewares.yml` | Shared middlewares (BasicAuth, security headers, rate limiting) |
| `authentik.yml` | ForwardAuth middleware for SSO stack integration |

## Adding Services from Other Stacks

Any service in another stack can be discovered by Traefik by:

1. Joining the `proxy` network
2. Adding Traefik labels

```yaml
# In another stack's docker-compose.yml
services:
  myapp:
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.${DOMAIN}`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.myapp.loadbalancer.server.port=8080"

networks:
  proxy:
    external: true
```

## Watchtower Notifications

Watchtower can notify on container updates via [Shoutrrr](https://containrrr.dev/shoutrrr/):

```bash
# ntfy (self-hosted)
WATCHTOWER_NOTIFICATION_URL=shoutrrr://ntfy/homelab-updates

# Gotify
WATCHTOWER_NOTIFICATION_URL=gotify://gotify.example.com/yourtoken

# Slack
WATCHTOWER_NOTIFICATION_URL=slack://hook.slack.com/services/T/B/token

# Email
WATCHTOWER_NOTIFICATION_URL=smtp://user:password@smtp.gmail.com:587/?from=x&to=y
```

## Troubleshooting

### Traefik dashboard not accessible
1. Check DNS: `nslookup traefik.yourdomain.com`
2. Check ports: `ss -tlnp | grep -E '80|443'`
3. Check logs: `docker logs traefik`
4. Verify ACME: `cat config/traefik/acme.json | jq .`

### Certificate errors
1. Ensure port 80 is accessible from the internet
2. Check ACME email is valid
3. Check rate limits: `docker logs traefik | grep acme`
4. For local dev, consider using a self-signed cert or `mkcert`

### Portainer admin password timeout
If you didn't set the admin password within 5 minutes of first start:
```bash
docker compose -f stacks/base/docker-compose.yml down
docker volume rm portainer-data
docker compose -f stacks/base/docker-compose.yml up -d
```

### Container can't connect to Docker API
All containers use the socket proxy. If a container needs Docker access:
1. Add it to the `socket-proxy` network
2. Set `DOCKER_HOST=tcp://docker-socket-proxy:2375`
3. Enable required API endpoints in the socket proxy environment