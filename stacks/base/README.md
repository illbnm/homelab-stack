# Base Infrastructure Stack

The foundation of HomeLab Stack. Must be deployed **before any other stack**.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Traefik | 3.1.6 | `traefik.<DOMAIN>` | Reverse proxy + TLS termination |
| Portainer CE | 2.21.4 | `portainer.<DOMAIN>` | Docker management UI |
| Watchtower | 1.7.1 | — | Automatic container updates |
| Docker Socket Proxy | 0.2.0 | — | Secure Docker API isolation |

## Architecture

```
Internet
    │
    ▼
[Traefik :443]
    │  TLS termination (Let's Encrypt)
    │  HTTP→HTTPS redirect
    │  Security headers + rate limiting
    │
    ├──► portainer.<DOMAIN>  → Portainer
    ├──► traefik.<DOMAIN>    → Traefik Dashboard (BasicAuth)
    └──► *.<DOMAIN>          → Other stacks via 'proxy' network

[Socket Proxy] ← Restricts Docker API access
    │
    ├──► Traefik (read-only: containers, networks, events)
    ├──► Portainer (read-only + container management)
    └──► Watchtower (read-only + update operations)

[proxy] ← shared Docker network — all stacks attach here
```

## Security Features

- **Docker Socket Proxy**: No direct `/var/run/docker.sock` access for services
- **Least Privilege**: Socket Proxy exposes only necessary API endpoints
- **BasicAuth Protection**: Traefik dashboard requires authentication
- **Security Headers**: HSTS, XSS protection, clickjacking prevention
- **TLS 1.2+**: Modern cipher suites, Mozilla Intermediate profile

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
docker network create proxy # create shared network
mkdir -p config/traefik
touch config/traefik/acme.json
chmod 600 config/traefik/acme.json
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
| `GOTIFY_URL` | — | Gotify URL for Watchtower notifications |
| `GOTIFY_TOKEN` | — | Gotify app token |
| `NTFY_URL` | — | ntfy server URL (default: https://ntfy.sh) |
| `NTFY_TOPIC` | — | ntfy topic for notifications |
| `CN_MODE` | — | `true` to use CN Docker mirrors |

### Generate Dashboard Password Hash

```bash
# Install htpasswd (Debian/Ubuntu)
sudo apt-get install -y apache2-utils

# Generate hash (replace 'yourpassword')
htpasswd -nbB admin 'yourpassword' | sed -e 's/\$$/\$\$/g'

# Paste output into .env as TRAEFIK_DASHBOARD_PASSWORD_HASH
```

## DNS Configuration

### Required DNS Records

Create the following A records pointing to your server's public IP:

| Record | Type | Value |
|--------|------|-------|
| `*.<DOMAIN>` | A | Your server IP |
| `traefik.<DOMAIN>` | A | Your server IP |
| `portainer.<DOMAIN>` | A | Your server IP |

Example (Cloudflare):
```
Type: A
Name: *
Content: 1.2.3.4
Proxy: DNS only (grey cloud)

Type: A
Name: traefik
Content: 1.2.3.4
Proxy: DNS only

Type: A
Name: portainer
Content: 1.2.3.4
Proxy: DNS only
```

## TLS Certificate Configuration

### HTTP-01 Challenge (Default)

Works for standard domains. Requires port 80 to be publicly accessible.

```yaml
# Already configured in traefik.yml
certificatesResolvers:
  letsencrypt:
    acme:
      email: "admin@yourdomain.com"
      storage: /acme.json
      httpChallenge:
        entryPoint: web
```

### DNS-01 Challenge (Wildcard Certificates)

For wildcard certificates or when port 80 is blocked.

1. Set your DNS provider API credentials in `.env`:
```bash
CF_API_TOKEN=your_cloudflare_token  # For Cloudflare
```

2. Update `traefik.yml` to use DNS challenge:
```yaml
certificatesResolvers:
  letsencrypt-dns:
    acme:
      email: "admin@yourdomain.com"
      storage: /acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
          - "8.8.8.8:53"
```

3. Update container labels to use `letsencrypt-dns` certresolver.

## Docker Socket Proxy Configuration

The Socket Proxy restricts Docker API access for security:

| Endpoint | Access | Purpose |
|----------|--------|---------|
| `CONTAINERS` | ✅ Read/Write | List, start, stop containers |
| `SERVICES` | ❌ Blocked | Swarm services (not needed) |
| `TASKS` | ✅ Read | Read task status |
| `SECRETS` | ❌ Blocked | Docker secrets (not needed) |
| `PLUGINS` | ❌ Blocked | Docker plugins (not needed) |
| `NETWORKS` | ✅ Read | Read network info |
| `VOLUMES` | ✅ Read | Read volume info |
| `IMAGES` | ✅ Read | Read image info |
| `INFO` | ✅ Read | Read system info |
| `EVENTS` | ✅ Read | Subscribe to Docker events |
| `PING` | ✅ | Health check |

To customize access, edit `stacks/base/docker-compose.yml` socket-proxy environment variables.

## Watchtower Configuration

### Update Schedule

Default: Daily at 3:00 AM (Asia/Shanghai timezone)

```yaml
WATCHTOWER_SCHEDULE=0 0 3 * * *
```

### Enable/Disable Auto-Update per Container

Add labels to your containers:

```yaml
labels:
  # Enable auto-update
  - "com.centurylinklabs.watchtower.enable=true"
  
  # Or disable auto-update
  - "com.centurylinklabs.watchtower.enable=false"
```

### Notifications

Watchtower integrates with Gotify and ntfy:

```bash
# In .env
GOTIFY_URL=http://gotify:80
GOTIFY_TOKEN=your_gotify_app_token
NTFY_TOPIC=homelab-updates
```

## Health Checks

All services include health checks:

```bash
# Check status
docker compose ps

# View logs
docker compose logs -f traefik
docker compose logs -f portainer
docker compose logs -f watchtower
docker compose logs -f socket-proxy
```

## Troubleshooting

### Certificates Not Issuing

1. Check DNS records are correct: `dig traefik.<DOMAIN>`
2. Verify port 80/443 are open: `curl -I http://<DOMAIN>`
3. Check Traefik logs: `docker compose logs traefik | grep acme`

### Socket Proxy Connection Refused

1. Verify socket-proxy is healthy: `docker compose ps socket-proxy`
2. Check socket-proxy logs: `docker compose logs socket-proxy`
3. Ensure `/var/run/docker.sock` permissions: `ls -la /var/run/docker.sock`

### Dashboard Not Accessible

1. Verify BasicAuth hash in `.env`
2. Check Traefik labels: `docker inspect traefik | grep -A5 labels`
3. Test locally: `curl -k https://traefik.<DOMAIN>`

## Testing

```bash
# Verify all containers are running
docker compose ps

# Test HTTP→HTTPS redirect
curl -I http://<DOMAIN>

# Test Traefik dashboard (requires auth)
curl -k -u admin:password https://traefik.<DOMAIN>

# Test Portainer
curl -k https://portainer.<DOMAIN>
```

## Next Steps

After deploying Base Stack:

1. ✅ Verify all services are healthy
2. ✅ Access Portainer and set admin password
3. ✅ Access Traefik dashboard and verify routers
4. ✅ Deploy SSO Stack (Authentik) for authentication
5. ✅ Deploy other stacks as needed

## File Structure

```
stacks/base/
├── docker-compose.yml      # Main compose file
└── README.md              # This file

config/traefik/
├── traefik.yml            # Traefik static config
├── acme.json              # Let's Encrypt certificates
└── dynamic/
    ├── middlewares.yml    # Security headers, auth, rate limiting
    ├── tls.yml            # TLS options
    └── authentik.yml      # Authentik integration (optional)
```
