# 🏗️ Base Infrastructure Stack

> The foundation of HomeLab Stack. Must be deployed **before any other stack**.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| **Traefik** | 3.1 | `https://traefik.${DOMAIN}` | Reverse proxy + TLS termination |
| **Portainer CE** | 2.21 | `https://portainer.${DOMAIN}` | Docker management UI |
| **Watchtower** | 1.7 | — | Automatic container updates |
| **Socket Proxy** | 0.2 | — | Secure Docker API access for Traefik |

## Architecture

```
Internet
    │
    ▼
[Traefik :443] ──→ socket-proxy ──→ Docker API (limited)
    │ TLS termination (Let's Encrypt)
    │ ForwardAuth → Authentik (optional)
    │
    ├──► traefik.${DOMAIN}    → Traefik Dashboard
    ├──► portainer.${DOMAIN}  → Portainer
    └──► *.${DOMAIN}          → Other stacks via 'proxy' network

[proxy] ← shared Docker network — all stacks attach here
```

## Why Socket Proxy?

Traefik needs read-only access to the Docker API to discover containers. Instead of giving it full `/var/run/docker.sock` access, **tecnativa/docker-socket-proxy** acts as a gatekeeper:

- ✅ Only exposes: containers, networks, services, tasks (read-only)
- ❌ Blocks: images, volumes, configs, secrets, swarm, exec, plugins
- 🛡️ Even if Traefik is compromised, the attacker can't escalate through Docker

**Portainer** and **Watchtower** still use the real socket — they need full Docker API access for their functions.

## Prerequisites

- Docker >= 24.0 with Compose v2 plugin
- Ports 80 and 443 open on your firewall
- A domain pointing to your server's IP (A record)

## Quick Start

```bash
# 1. Create the shared Docker network (once)
docker network create proxy

# 2. Setup Traefik TLS
touch config/traefik/acme.json && chmod 600 config/traefik/acme.json

# 3. Copy and fill environment
cp stacks/base/.env.example .env
# Edit .env — set DOMAIN, ACME_EMAIL, TRAEFIK_DASHBOARD_PASSWORD_HASH

# 4. Launch
docker compose -f stacks/base/docker-compose.yml up -d
```

## Configuration

### Environment Variables

See [`.env.example`](.env.example) for all configurable options.

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain, e.g. `home.example.com` |
| `ACME_EMAIL` | ✅ | Email for Let's Encrypt notifications |
| `TRAEFIK_DASHBOARD_USER` | ✅ | Dashboard login username |
| `TRAEFIK_DASHBOARD_PASSWORD_HASH` | ✅ | Bcrypt hash — see below |
| `TZ` | ✅ | Timezone, e.g. `Asia/Shanghai` |
| `NTFY_TOKEN` | — | ntfy token for Watchtower notifications |
| `WATCHTOWER_NOTIFICATIONS` | — | Notification method (`ntfy` by default) |

### Generate Dashboard Password Hash

```bash
# Install htpasswd (Debian/Ubuntu)
sudo apt-get install -y apache2-utils

# Generate hash
htpasswd -nbB admin 'yourpassword' | sed -e 's/\$/\$\$/g'

# Paste output into .env as TRAEFIK_DASHBOARD_PASSWORD_HASH
```

### TLS Certificates

Traefik uses Let's Encrypt HTTP-01 challenge by default. For wildcard certificates, switch to the DNS challenge in `config/traefik/traefik.yml`:

```yaml
certificatesResolvers:
  letsencrypt-dns:
    acme:
      dnsChallenge:
        provider: cloudflare
```

Then set `CF_API_TOKEN` in your `.env`.

## How Other Stacks Connect

Any service that needs to be accessible via HTTPS must:

1. Join the `proxy` Docker network:
   ```yaml
   networks:
     - proxy
   ```

2. Add Traefik labels:
   ```yaml
   labels:
     - "traefik.enable=true"
     - "traefik.http.routers.myapp.rule=Host(`myapp.${DOMAIN}`)"
     - "traefik.http.routers.myapp.entrypoints=websecure"
     - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
     - "traefik.http.services.myapp.loadbalancer.server.port=8080"
   ```

3. Ensure the network exists at the top level:
   ```yaml
   networks:
     proxy:
       external: true
   ```

## Health Checks

All containers include health checks:

```bash
# Check all base services
docker ps --filter "label=com.docker.compose.project=base" --format "table {{.Names}}\t{{.Status}}"

# Verify Traefik ping
curl -sk https://traefik.${DOMAIN}/ping
```

## Troubleshooting

### Traefik can't discover containers

```bash
# Check socket-proxy is healthy
docker logs socket-proxy

# Check Traefik provider config
cat config/traefik/traefik.yml | grep endpoint
# Should be: unix:///var/run/docker.sock  (mapped by socket-proxy)
```

### Certificates not generating

```bash
# Check ACME file permissions
ls -la config/traefik/acme.json
# Must be 600

# Check Traefik logs
docker logs traefik --tail 50
```

### Port 80/443 already in use

```bash
sudo ss -tlnp | grep -E ':80 |:443 '
```
