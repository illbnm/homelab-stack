# Base Infrastructure Stack

Reverse proxy with automatic TLS + Docker management UI + automatic container updates.

**Components:**
- [Traefik v3](https://traefik.io/) — Reverse proxy with Let's Encrypt TLS
- [Portainer CE](https://www.portainer.io/) — Web UI for Docker management
- [Watchtower](https://containrrr.dev/watchtower/) — Automatic Docker image updates

## Prerequisites

- Docker + Docker Compose v2
- A domain name pointing to your server's public IP
- Ports 80 and 443 open in your firewall

## Quick Start

**1. Create the shared proxy network** (only once, shared across all stacks):
```bash
docker network create proxy
```

**2. Initialize the ACME certificate storage** (required by Traefik):
```bash
mkdir -p ../../config/traefik/data ../../config/traefik/logs
touch ../../config/traefik/data/acme.json
chmod 600 ../../config/traefik/data/acme.json
```

**3. Configure your environment:**
```bash
cp .env.example .env
nano .env  # Set DOMAIN, ACME_EMAIL, TRAEFIK_AUTH
```

**4. Generate a Traefik dashboard password:**
```bash
# Install htpasswd: apt install apache2-utils
echo $(htpasswd -nb admin yourpassword) | sed -e 's/\$/\$\$/g'
# Paste the output as TRAEFIK_AUTH in .env
```

**5. Start the stack:**
```bash
docker compose up -d
```

**6. Verify services are running:**
```bash
docker compose ps
docker compose logs traefik --tail 20
```

## Access

| Service | URL |
|---------|-----|
| Traefik Dashboard | `https://traefik.YOUR_DOMAIN` |
| Portainer | `https://portainer.YOUR_DOMAIN` |

Both are restricted to LAN access only by default.

## Adding Services to Traefik

Any Docker Compose service can be exposed via Traefik by adding labels:

```yaml
networks:
  - proxy

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`myapp.${DOMAIN}`)"
  - "traefik.http.routers.myapp.entrypoints=websecure"
  - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
  - "traefik.http.services.myapp.loadbalancer.server.port=8080"
```

## DNS Challenge (for servers behind NAT)

If your server is not directly reachable on port 80, use a DNS challenge instead of HTTP challenge. Edit `config/traefik/traefik.yml`:

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      dnsChallenge:
        provider: cloudflare  # or: aliyun, dnspod, huaweicloud
        delayBeforeCheck: 30
```

Supported providers: https://doc.traefik.io/traefik/https/acme/#providers

## Watchtower

Watchtower checks for image updates daily at 04:00 and restarts containers with newer images. To exclude a container from updates, add:

```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=false"
```

## Troubleshooting

**TLS certificate not issued:**
```bash
# Check Traefik logs
docker logs traefik --tail 50

# Verify port 80 is reachable from internet (required for HTTP challenge)
curl http://YOUR_DOMAIN/.well-known/acme-challenge/test

# Use staging resolver first to avoid rate limits
# In docker-compose.yml, change certresolver to: letsencrypt-staging
```

**Cannot access dashboard:**
```bash
# Verify you're on LAN (192.168.x.x / 10.x.x.x)
# Check if traefik container is healthy
docker inspect traefik --format='{{.State.Health.Status}}'
```
