# Base Infrastructure Stack

The foundation of HomeLab Stack. Must be deployed **before any other stack**.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Traefik | v3.1.6 | `traefik.<DOMAIN>` | Reverse proxy + auto HTTPS |
| Portainer CE | 2.21.3 | `portainer.<DOMAIN>` | Docker management UI |
| Watchtower | 1.7.1 | — | Automatic container updates |
| Socket Proxy | 0.2.0 | — | Secure Docker socket isolation |

## Architecture

```
Internet
    │
    ▼
[Traefik :443]  ←──── reads container labels via ────┐
    │  TLS termination (Let's Encrypt)                 │
    │                                                   │
    ├──► traefik.<DOMAIN>    → Traefik Dashboard        │
    ├──► portainer.<DOMAIN>  → Portainer                │
    └──► *.<DOMAIN>          → Other stacks             │
                                                      │
[Socket Proxy :2375]  ←── secures docker.sock ────────┘
    ▲
    └── docker.sock (read-only)

[Watchtower] → scans daily 3 AM, updates labeled containers

[proxy] ← shared Docker network — all stacks attach here
```

## Prerequisites

- Docker >= 24.0 with Compose v2 plugin
- Ports 80 and 443 open on your firewall
- A domain with DNS A record pointing to your server's public IP

## DNS Configuration

Create the following DNS records pointing to your server's IP:

| Record | Type | Value | Purpose |
|--------|------|-------|---------|
| `traefik.<DOMAIN>` | A | `<SERVER_IP>` | Traefik Dashboard |
| `portainer.<DOMAIN>` | A | `<SERVER_IP>` | Portainer UI |
| `*.home.<DOMAIN>` | A | `<SERVER_IP>` | Wildcard for all services |

> **Tip:** If using Cloudflare, enable the proxy (orange cloud) for DDoS protection.  
> For wildcard certs, you'll need DNS challenge (see below).

## Quick Start

```bash
# 1. Create the shared proxy network (once, globally)
docker network create proxy

# 2. Create .env from template and fill in your values
cd stacks/base
cp .env.example .env
nano .env

# 3. Create ACME storage file with correct permissions
touch ../../config/traefik/acme.json
chmod 600 ../../config/traefik/acme.json

# 4. Generate dashboard password hash
echo $(htpasswd -nbB admin 'YOUR_PASSWORD') | sed -e 's/\$/\$\$/g'
# ↑ Paste output into .env as TRAEFIK_AUTH

# 5. Edit Traefik static config email (or use envsubst)
#    config/traefik/traefik.yml → certificatesResolvers → acme → email

# 6. Launch!
docker compose up -d

# 7. Verify all 4 containers are healthy
docker compose ps
```

## Configuration

### Environment Variables (`.env.example`)

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain, e.g. `home.example.com` |
| `ACME_EMAIL` | ✅ | Email for Let's Encrypt notifications |
| `TRAEFIK_AUTH` | ✅ | Bcrypt `user:hash` — see generation below |
| `TZ` | ✅ | Timezone, e.g. `Asia/Shanghai` |
| `WATCHTOWER_NOTIFICATION_URL` | — | ntfy notification URL |
| `WATCHTOWER_GOTIFY_URL` | — | Gotify server URL |
| `WATCHTOWER_GOTIFY_TOKEN` | — | Gotify app token |
| `CN_MODE` | — | `true` to use CN Docker mirrors |

### Generate Dashboard Password Hash

```bash
# Install htpasswd (Debian/Ubuntu)
sudo apt-get install -y apache2-utils

# Generate bcrypt hash (replace 'yourpassword')
echo $(htpasswd -nbB admin 'yourpassword') | sed -e 's/\$/\$\$/g'

# Copy output → paste into .env as TRAEFIK_AUTH
```

### TLS / Certificate Configuration

Traefik uses **Let's Encrypt** for automatic TLS certificates.

**HTTP Challenge (default, single-domain certs):**
- Works out of the box — no DNS provider config needed
- Requires port 80 accessible from the internet
- Configured in `config/traefik/traefik.yml` under `certificatesResolvers.letsencrypt`

**DNS Challenge (wildcard certs):**
- Requires a DNS provider API token (Cloudflare, Route53, etc.)
- Enable in `config/traefik/traefik.yml` under `certificatesResolvers.letsencrypt-dns`
- Set `CF_DNS_API_TOKEN` (or provider-specific var) in your environment
- Use via router label: `traefik.http.routers.<name>.tls.certresolver=letsencrypt-dns`

**Editing the email in traefik.yml:**
```bash
# Replace the placeholder email in both resolvers
sed -i 's/admin@yourdomain.com/YOUR_EMAIL/g' config/traefik/traefik.yml
```

### Docker Socket Proxy

All Docker API access is routed through `docker-socket-proxy` for security:
- Traefik reads container labels via `tcp://socket-proxy:2375`
- Portainer manages containers via the same proxy
- Only the minimum API endpoints are enabled (containers, networks, services, tasks, events, info)
- Watchtower still mounts docker.sock directly as it requires direct container lifecycle control

### Watchtower Notifications

Watchtower sends update notifications via one of:

1. **ntfy** (recommended): Set `WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.sh/your-topic`
2. **Gotify**: Set both `WATCHTOWER_GOTIFY_URL` and `WATCHTOWER_GOTIFY_TOKEN`

Containers must have this label to be auto-updated:
```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=true"
```

## Adding Other Stacks

Any new service can be accessed via Traefik by joining the `proxy` network:

```yaml
services:
  my-app:
    image: my-app:latest
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-app.rule=Host(`my-app.${DOMAIN}`)"
      - "traefik.http.routers.my-app.entrypoints=websecure"
      - "traefik.http.routers.my-app.tls.certresolver=letsencrypt"
      - "traefik.http.services.my-app.loadbalancer.server.port=8080"
      - "com.centurylinklabs.watchtower.enable=true"  # auto-update

networks:
  proxy:
    external: true
```

## Troubleshooting

```bash
# Check container health
docker compose ps

# Traefik logs
docker compose logs traefik --tail 50

# Watchtower logs (check for update activity)
docker compose logs watchtower --tail 50

# Socket proxy connectivity test
docker exec traefik wget -qO- http://socket-proxy:2375/_ping

# Regenerate acme.json if certificates are stuck
docker compose down
rm -f ../../config/traefik/acme.json
touch ../../config/traefik/acme.json && chmod 600 ../../config/traefik/acme.json
docker compose up -d
```

## Verification Checklist

- [ ] `docker compose up -d` starts all 4 containers (traefik, portainer, watchtower, socket-proxy)
- [ ] All containers report healthy status
- [ ] `http://<SERVER_IP>:80` redirects to HTTPS automatically
- [ ] `https://traefik.<DOMAIN>` shows Dashboard (requires Basic Auth)
- [ ] `https://portainer.<DOMAIN>` shows Portainer UI
- [ ] Other stack containers on `proxy` network are discovered by Traefik
- [ ] Watchtower scans at 3:00 AM and sends notifications
