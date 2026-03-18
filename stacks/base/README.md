# Base Infrastructure Stack

The foundation of HomeLab Stack. Must be deployed **before any other stack**.

## What's Included

| Service | Image | Version | URL | Purpose |
|---------|-------|---------|-----|---------|
| Traefik | `traefik` | `v3.1.6` | `traefik.<DOMAIN>` | Reverse proxy + auto HTTPS |
| Portainer CE | `portainer/portainer-ce` | `2.21.3` | `portainer.<DOMAIN>` | Docker management UI |
| Watchtower | `containrrr/watchtower` | `1.7.1` | — | Automatic container updates |
| Socket Proxy | `tecnativa/docker-socket-proxy` | `0.2.0` | — | Secure Docker socket isolation |

## Architecture

```
Internet
    │
    ▼
[Traefik :80/:443]
    │  HTTP → auto-redirect HTTPS
    │  TLS termination (Let's Encrypt)
    │  ForwardAuth → Authentik (optional)
    │
    ├──► traefik.<DOMAIN>    → Traefik Dashboard (BasicAuth protected)
    ├──► portainer.<DOMAIN>  → Portainer CE
    └──► *.<DOMAIN>          → Other stacks via 'proxy' network

                    ┌──────────────┐
                    │ socket-proxy │ ← internal network only
                    │  :2375 (ro)  │
                    └──────┬───────┘
                           │
                    /var/run/docker.sock

[proxy]    ← shared external Docker network — all stacks attach here
[socket-proxy] ← internal network — only Traefik ↔ Socket Proxy
```

### Docker Socket Security

Traefik **never** mounts the Docker socket directly. Instead, `docker-socket-proxy` exposes a
read-only, filtered API on an internal-only network. Only `CONTAINERS`, `NETWORKS`, `SERVICES`,
and `TASKS` endpoints are enabled — all write operations are denied.

## Prerequisites

- Docker >= 24.0 with Compose v2 plugin
- Ports 80 and 443 open on your firewall
- A domain with DNS A record(s) pointing to your server IP:
  - `traefik.<DOMAIN>` → server IP
  - `portainer.<DOMAIN>` → server IP
  - (or use a wildcard: `*.<DOMAIN>` → server IP)

## Quick Start

```bash
# 1. Create the shared proxy network
docker network create proxy

# 2. Create and secure acme.json for Let's Encrypt certificates
touch config/traefik/acme.json
chmod 600 config/traefik/acme.json

# 3. Generate Traefik dashboard password
sudo apt-get install -y apache2-utils    # skip if htpasswd is installed
htpasswd -nbB admin 'your-secure-password' > config/traefik/dynamic/.htpasswd

# 4. Configure environment variables
cd stacks/base
cp .env.example .env
# Edit .env — set DOMAIN, ACME_EMAIL, TZ at minimum

# 5. Launch
docker compose up -d
```

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | — | Base domain, e.g. `home.example.com` |
| `ACME_EMAIL` | Yes | — | Email for Let's Encrypt notifications |
| `TZ` | Yes | `Asia/Shanghai` | Server timezone |
| `WATCHTOWER_NOTIFICATION_URL` | No | — | Gotify/ntfy URL for update notifications |

### TLS Certificates

Traefik uses Let's Encrypt with HTTP-01 challenge by default. Certificates are automatically
obtained and renewed for any service with the `tls.certresolver=letsencrypt` label.

For **wildcard certificates** (requires DNS challenge), update `config/traefik/traefik.yml`:
- Set `certificatesResolvers.letsencrypt-dns.acme.email` to your email
- Set the DNS provider (default: `cloudflare`)
- Add `CF_API_TOKEN` to your environment

### Dashboard Authentication

The Traefik dashboard at `traefik.<DOMAIN>` is protected by HTTP Basic Auth. The credentials
are stored in `config/traefik/dynamic/.htpasswd`.

To update the password:

```bash
htpasswd -nbB admin 'new-password' > config/traefik/dynamic/.htpasswd
# Traefik picks up changes automatically (file provider watches /dynamic)
```

### Watchtower

Watchtower runs daily at **03:00 AM** (server timezone) and only updates containers with
the label `com.centurylinklabs.watchtower.enable=true`.

**Notifications** — configure `WATCHTOWER_NOTIFICATION_URL` in `.env`:

```bash
# Gotify
WATCHTOWER_NOTIFICATION_URL=gotify://gotify.example.com/YOUR_APP_TOKEN

# ntfy
WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.example.com/homelab-updates
```

## Adding Other Stacks

All other stacks connect to Traefik via the shared `proxy` network. In your stack's
`docker-compose.yml`:

```yaml
services:
  my-app:
    # ...
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-app.rule=Host(`app.${DOMAIN}`)"
      - "traefik.http.routers.my-app.entrypoints=websecure"
      - "traefik.http.routers.my-app.tls.certresolver=letsencrypt"
      - "traefik.http.services.my-app.loadbalancer.server.port=8080"

networks:
  proxy:
    external: true
```

## Health Checks

All 4 containers include health checks. Verify with:

```bash
docker compose ps
```

Expected output:

```
NAME            IMAGE                                   STATUS
socket-proxy    tecnativa/docker-socket-proxy:0.2.0     Up (healthy)
traefik         traefik:v3.1.6                          Up (healthy)
portainer       portainer/portainer-ce:2.21.3           Up (healthy)
watchtower      containrrr/watchtower:1.7.1             Up (healthy)
```

## Verification

```bash
# All containers running and healthy
docker compose ps

# Traefik dashboard accessible (should return 401 without auth)
curl -sk https://traefik.${DOMAIN} -o /dev/null -w "%{http_code}"
# Expected: 401

# Portainer accessible
curl -sk https://portainer.${DOMAIN} -o /dev/null -w "%{http_code}"
# Expected: 200 or 302

# HTTP auto-redirects to HTTPS
curl -sI http://traefik.${DOMAIN} 2>&1 | grep -i location
# Expected: Location: https://traefik.${DOMAIN}/

# Socket proxy internal only (should fail from host)
curl -s http://localhost:2375/_ping
# Expected: connection refused (not exposed to host)
```

## Troubleshooting

**Traefik won't start / unhealthy**
- Check socket-proxy is healthy first: `docker logs socket-proxy`
- Verify `acme.json` exists and has `chmod 600`
- Check Traefik logs: `docker logs traefik`

**Certificate errors**
- Ensure ports 80/443 are open and reachable from the internet
- Check ACME email is set in `config/traefik/traefik.yml`
- View ACME state: `cat config/traefik/acme.json | python3 -m json.tool`

**Portainer not accessible**
- Confirm it joined the proxy network: `docker network inspect proxy`
- Check Traefik dashboard for the portainer router/service

**Watchtower not sending notifications**
- Check `WATCHTOWER_NOTIFICATION_URL` format in `.env`
- View Watchtower logs: `docker logs watchtower`
