# 🏠 Base Infrastructure Stack

> Traefik v3.1.6 · Socket Proxy · Portainer CE 2.21.3 · Watchtower 1.7.1

The base infrastructure layer. All other HomeLab stacks depend on this one — it provides reverse proxying, automatic HTTPS, container management, and scheduled updates.

---

## Services

| Service | Image | Role | Default URL |
|---------|-------|------|-------------|
| **Traefik** | `traefik:v3.1.6` | Reverse proxy + HTTPS + routing | `https://traefik.${DOMAIN}` |
| **Socket Proxy** | `tecnativa/docker-socket-proxy:0.2.0` | Secure Docker API gateway | Internal only |
| **Portainer CE** | `portainer/portainer-ce:2.21.3` | Docker management UI | `https://portainer.${DOMAIN}` |
| **Watchtower** | `containrrr/watchtower:1.7.1` | Scheduled container updates | Internal only |

---

## Prerequisites

- Docker Engine 24+
- Docker Compose v2.20+
- A domain name with DNS pointing to your server's IP
- Ports 80 and 443 open on your firewall

---

## Quick Start

### 1. Create the shared proxy network

This network is used by all stacks to connect to Traefik. **Create it once.**

```bash
docker network create proxy
```

### 2. Prepare directories

```bash
# Traefik log directory
sudo mkdir -p /var/log/traefik
sudo chmod 755 /var/log/traefik

# Traefik auth directory (for dashboard Basic Auth)
mkdir -p ../../config/traefik/auth
```

### 3. Generate Traefik dashboard credentials

```bash
# Install htpasswd (if not available)
sudo apt-get install -y apache2-utils   # Ubuntu/Debian
# or: brew install httpd                # macOS

# Generate credentials
htpasswd -nb admin 'your-secure-password'
# Output: admin:$apr1$xyz...

# Copy the output and escape $ signs for docker-compose:
# Replace each $ with $$  (e.g. $apr1$ → $$apr1$$)

# Write to auth file
htpasswd -cb ../../config/traefik/auth/.htpasswd admin 'your-secure-password'
```

### 4. Configure environment

```bash
cp .env.example .env
nano .env
```

Required variables to set:

| Variable | Description | Example |
|----------|-------------|---------|
| `DOMAIN` | Your base domain | `home.example.com` |
| `ACME_EMAIL` | Email for Let's Encrypt | `admin@example.com` |
| `WATCHTOWER_API_TOKEN` | Random token for Watchtower API | `openssl rand -hex 16` |
| `TZ` | Your timezone | `Asia/Shanghai` |

### 5. Configure DNS

Create DNS A records pointing to your server's public IP:

```
traefik.yourdomain.com     → YOUR_SERVER_IP
portainer.yourdomain.com   → YOUR_SERVER_IP
```

For local/LAN use, add entries to `/etc/hosts`:

```
192.168.1.100  traefik.home.local portainer.home.local
```

### 6. Launch

```bash
docker compose up -d
```

Check status:

```bash
docker compose ps
docker compose logs -f traefik
```

---

## Port Reference

| Port | Protocol | Purpose |
|------|----------|---------|
| `80` | TCP | HTTP → auto-redirects to HTTPS |
| `443` | TCP | HTTPS (TLS termination) |
| `443` | UDP | HTTP/3 (QUIC) |
| `2375` | TCP | Docker API (internal, socket-proxy only) |
| `8080` | TCP | Watchtower HTTP API (internal) |
| `8082` | TCP | Traefik Prometheus metrics (internal) |
| `9000` | TCP | Portainer UI (internal, via Traefik) |
| `8000` | TCP | Portainer Edge Agent (internal, via Traefik) |

---

## Service Access

### Traefik Dashboard

URL: `https://traefik.${DOMAIN}`

- Protected by Basic Auth (credentials set in step 3)
- Shows all routers, services, middlewares, and TLS certificates

### Portainer CE

URL: `https://portainer.${DOMAIN}`

- Set your admin password **within 5 minutes** of first launch
- If you miss the window: `docker restart portainer`
- Manages all containers via socket proxy (read-write)

### Watchtower

- No UI — runs as a background service
- Updates containers daily at **03:00** (configurable via `WATCHTOWER_SCHEDULE`)
- Only updates containers with label `com.centurylinklabs.watchtower.enable=true`
- Check logs: `docker logs watchtower`

---

## HTTPS / Certificate Configuration

### HTTP Challenge (default)

Works out of the box. Let's Encrypt verifies domain ownership via port 80.

Requirements:
- Port 80 must be open and reachable from the internet
- DNS must resolve to your server

### DNS Challenge (for wildcard certs)

Required if port 80 is not publicly accessible, or to issue `*.yourdomain.com`.

Edit `../../config/traefik/traefik.yml`, uncomment `dnsChallenge` and comment out `httpChallenge`:

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: "${ACME_EMAIL}"
      storage: /certificates/acme.json
      dnsChallenge:
        provider: cloudflare   # your DNS provider
        resolvers:
          - "1.1.1.1:53"
```

Add provider credentials to `.env`:

```bash
# Cloudflare example
CF_DNS_API_TOKEN=your_cloudflare_zone_edit_token
```

Supported providers: https://doc.traefik.io/traefik/https/acme/#providers

### Staging / Testing

To avoid Let's Encrypt rate limits while testing, switch the cert resolver to staging:

In `docker-compose.yml`, change all `certresolver: letsencrypt` to `certresolver: letsencrypt-staging`.
Staging certs are not trusted by browsers but confirm the flow works.

---

## Adding Other Stacks to Traefik

Other stacks connect to Traefik through the shared `proxy` network. Minimal example:

```yaml
# In your other stack's docker-compose.yml:
networks:
  proxy:
    external: true

services:
  myapp:
    image: myapp:1.0.0
    networks:
      - proxy
    labels:
      traefik.enable: "true"
      traefik.http.routers.myapp.rule: "Host(`myapp.${DOMAIN}`)"
      traefik.http.routers.myapp.entrypoints: "websecure"
      traefik.http.routers.myapp.tls.certresolver: "letsencrypt"
      traefik.http.services.myapp.loadbalancer.server.port: "3000"
      # Opt into Watchtower updates:
      com.centurylinklabs.watchtower.enable: "true"
```

---

## Watchtower Configuration

### Schedule

The default schedule runs at 03:00 daily. To customise, edit `WATCHTOWER_SCHEDULE` in `.env`:

```bash
# Format: seconds minutes hours day-of-month month day-of-week
WATCHTOWER_SCHEDULE=0 0 3 * * *     # Daily at 03:00 (default)
WATCHTOWER_SCHEDULE=0 0 */6 * * *   # Every 6 hours
WATCHTOWER_SCHEDULE=0 30 2 * * 0    # Every Sunday at 02:30
```

### Opt-in Labelling

Only containers with this label get updated:

```yaml
labels:
  com.centurylinklabs.watchtower.enable: "true"
```

To exclude a container explicitly:

```yaml
labels:
  com.centurylinklabs.watchtower.enable: "false"
```

### Notifications

After deploying the Notifications Stack, set:

```bash
# In .env:
WATCHTOWER_NOTIFICATION_URL=gotify://gotify.yourdomain.com/YOUR_TOKEN
# or
WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.yourdomain.com/homelab-updates
```

---

## Security Notes

### Docker Socket Proxy

This stack uses `tecnativa/docker-socket-proxy` to restrict Docker API access:
- Traefik connects to the proxy (port 2375) instead of the raw socket
- Only `CONTAINERS`, `NETWORKS`, `EVENTS`, and `VERSION` endpoints are exposed
- Write operations (`POST`, `DELETE`) are denied
- Portainer connects separately with broader access for management

### Dashboard Auth

The Traefik dashboard is protected by Basic Auth via `.htpasswd`. The auth file lives in `../../config/traefik/auth/` and is mounted read-only into the container.

Do not expose the dashboard without authentication.

---

## Troubleshooting

### Containers don't start

```bash
docker compose logs socket-proxy
docker compose logs traefik
docker compose logs portainer
```

### Certificate issues

Check Traefik logs for ACME errors:

```bash
docker compose logs traefik | grep -i acme
docker compose logs traefik | grep -i error
```

Common causes:
- Port 80 not reachable from internet (HTTP challenge)
- DNS not yet propagated
- Let's Encrypt rate limit hit — switch to `letsencrypt-staging` for testing

### Dashboard returns 401 Unauthorized

Regenerate the `.htpasswd` file:

```bash
htpasswd -cb ../../config/traefik/auth/.htpasswd admin 'your-password'
docker restart traefik
```

### Portainer password not set in time

```bash
docker restart portainer
# Then immediately open https://portainer.${DOMAIN} and set password
```

### Container not appearing in Traefik

1. Confirm the container has `traefik.enable: "true"` label
2. Confirm it's on the `proxy` network
3. Check Traefik dashboard → HTTP Routers for errors
4. Check logs: `docker logs traefik | grep error`

---

## File Structure

```
stacks/base/
├── docker-compose.yml      # Main compose file
├── .env.example            # Environment variable template
└── README.md               # This file

config/traefik/
├── traefik.yml             # Static configuration (entry points, providers, ACME)
├── auth/
│   └── .htpasswd           # Dashboard auth (create with htpasswd -cb ...)
└── dynamic/
    ├── tls.yml             # TLS version + cipher options
    └── middlewares.yml     # Reusable middleware chains
```

---

## CN Network Notes

For users in China, Docker Hub images may be slow. Alternative mirrors:

```bash
# /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://mirror.baidubce.com"
  ]
}
```

Images used in this stack are on Docker Hub and generally accessible.
Traefik's ACME (Let's Encrypt) requires outbound HTTPS — use a proxy if needed:

```yaml
# In docker-compose.yml, under traefik environment:
- LEGO_CA_CERTIFICATES=/certificates/ca.crt   # custom CA if behind MITM proxy
- HTTPS_PROXY=http://your-proxy:3128
```
