# Base Infrastructure Stack

The foundation of HomeLab Stack. Must be deployed **before any other stack**.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Traefik | 3.1.6 | `traefik.<DOMAIN>` | Reverse proxy + TLS termination |
| Portainer CE | 2.21.4 | `portainer.<DOMAIN>` | Docker management UI |
| Watchtower | 1.7.1 | - | Automatic container updates |
| Docker Socket Proxy | 0.2.0 | - | Docker socket security isolation |

## Architecture

```
Internet
    |
    v
[Traefik :443]
    |  TLS termination (Let's Encrypt)
    |  ForwardAuth -> Authentik (optional, via SSO stack)
    |
    +--> portainer.<DOMAIN>  -> Portainer
    +--> traefik.<DOMAIN>    -> Traefik Dashboard (BasicAuth)
    +--> *.<DOMAIN>          -> Other stacks via 'proxy' network

[Docker Socket Proxy]  <- isolates Docker API access
    |
    +--> Traefik (read-only: containers, services, tasks, networks)
    +--> Portainer (read-only via same proxy)

[proxy] <- shared Docker network - all stacks attach here
```

## Security

**Docker Socket Proxy** isolates the Docker socket from all services:
- Traefik connects via `tcp://docker-socket-proxy:2375` (read-only API subset)
- Portainer connects via the same proxy
- No container gets direct `/var/run/docker.sock` access (except Watchtower, which needs it for updates)

## Prerequisites

- Docker >= 24.0 with Compose v2 plugin
- Ports 80 and 443 open on your firewall
- A domain pointing to your server's IP (A record)
- `./scripts/setup-env.sh` completed (creates `.env` and `acme.json`)

## Quick Start

```bash
# 1. Create the shared proxy network
docker network create proxy

# 2. Copy and edit environment variables
cd stacks/base
cp .env.example .env
# Edit .env with your domain, email, and password hash

# 3. Create ACME certificate storage
touch ../../config/traefik/acme.json
chmod 600 ../../config/traefik/acme.json

# 4. Generate dashboard password hash
htpasswd -nbB admin 'yourpassword' | sed -e 's/\$/\$\$/g'
# Copy output to .env as TRAEFIK_DASHBOARD_PASSWORD_HASH

# 5. Create .htpasswd file for dynamic auth
echo 'admin:$2y$05$...' > ../../config/traefik/dynamic/.htpasswd

# 6. Start the stack
docker compose up -d

# 7. Verify all containers are healthy
docker compose ps
```

## DNS Configuration

Point your domain's DNS to your server:

```
A    @          -> your.server.ip
A    *          -> your.server.ip   (wildcard for all subdomains)
```

Or create individual records:
```
A    traefik    -> your.server.ip
A    portainer  -> your.server.ip
```

## TLS Certificate Configuration

### Option A: HTTP Challenge (Default)

Works out of the box. Requires port 80 to be publicly accessible.
No additional configuration needed.

### Option B: DNS Challenge (Wildcard Certificates)

Set in `.env`:
```bash
DNS_CHALLENGE_PROVIDER=cloudflare
CF_API_EMAIL=your@email.com
CF_API_KEY=your-api-key
```

Then update `config/traefik/traefik.yml` to use `letsencrypt-dns` resolver.

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | - | Base domain |
| `ACME_EMAIL` | Yes | - | Email for Let's Encrypt |
| `TZ` | Yes | - | Timezone |
| `TRAEFIK_DASHBOARD_USER` | No | admin | Dashboard username |
| `TRAEFIK_DASHBOARD_PASSWORD_HASH` | Yes | - | Bcrypt password hash |
| `WATCHTOWER_NOTIFY_URL` | No | - | ntfy notification URL |
| `CN_MODE` | No | false | Use China Docker mirrors |
| `DNS_CHALLENGE_PROVIDER` | No | - | DNS provider for LE DNS challenge |

## Adding Other Stacks

All other stacks join the `proxy` network to be accessible via Traefik:

```yaml
# In any other stack's docker-compose.yml:
networks:
  proxy:
    external: true

services:
  myservice:
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myservice.rule=Host(`myservice.${DOMAIN}`)"
      - "traefik.http.routers.myservice.entrypoints=websecure"
      - "traefik.http.routers.myservice.tls.certresolver=letsencrypt"
```

## Health Checks

All 4 services have health checks configured:

| Service | Check | Interval |
|---------|-------|----------|
| Traefik | `traefik healthcheck --ping` | 30s |
| Portainer | `/portainer --version` | 30s |
| Watchtower | `/watchtower --health-check` | 30s |
| Socket Proxy | `wget /version` | 30s |

## Troubleshooting

### Port 80/443 already in use
```bash
sudo lsof -i :80 -i :443
# Stop conflicting service (e.g., nginx, apache)
```

### Certificate not issued
- Ensure port 80 is open: `curl http://your-domain/.well-known/acme-challenge/test`
- Check Traefik logs: `docker compose logs traefik`
- Verify DNS propagation: `dig your-domain.com`

### Traefik can't discover containers
- Ensure containers have `traefik.enable=true` label
- Ensure containers are on the `proxy` network
- Check socket proxy logs: `docker compose logs docker-socket-proxy`
