# 🏗️ Base Infrastructure Stack

Core infrastructure layer for HomeLab Stack. **All other stacks depend on this one.**

Provides: reverse proxy with automatic HTTPS, Docker management UI, and automated container updates.

## Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| Traefik v3 | `traefik:v3.1.6` | 80, 443 | Reverse proxy + automatic TLS |
| Docker Socket Proxy | `tecnativa/docker-socket-proxy:0.2.0` | internal | Secure Docker API isolation |
| Portainer CE | `portainer/portainer-ce:2.21.3` | 9000 (internal) | Docker management UI |
| Watchtower | `containrrr/watchtower:1.7.1` | — | Automated container updates |

## Prerequisites

- Docker Engine 24+ and Docker Compose v2
- A domain name with DNS pointing to your server
- Ports 80 and 443 open on your firewall/router

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/illbnm/homelab-stack.git
cd homelab-stack

# 2. Configure environment
cp stacks/base/.env.example stacks/base/.env
nano stacks/base/.env   # fill in DOMAIN, ACME_EMAIL, TRAEFIK_AUTH

# 3. Generate Traefik Basic Auth password
echo $(htpasswd -nb admin yourpassword) | sed -e 's/\$/\$\$/g'
# Paste the output as TRAEFIK_AUTH in .env

# 4. Start the stack
cd stacks/base
docker compose up -d

# 5. Check status
docker compose ps
```

## DNS Configuration

Point your DNS records to your server's public IP:

```
A    @                 <YOUR_SERVER_IP>
A    traefik           <YOUR_SERVER_IP>
A    portainer         <YOUR_SERVER_IP>
# Add wildcard to cover all future subdomains:
A    *                 <YOUR_SERVER_IP>
```

## Certificate Configuration

### Option 1: HTTP Challenge (default, works behind standard NAT)

The default `config/traefik/traefik.yml` uses HTTP challenge. Ensure port 80 is publicly accessible.

### Option 2: DNS Challenge (works behind NAT, supports wildcards)

Edit `config/traefik/traefik.yml` and configure your DNS provider:

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      dnsChallenge:
        provider: cloudflare   # or route53, digitalocean, etc.
```

Set provider credentials as environment variables:
```bash
# Cloudflare example
CF_DNS_API_TOKEN=your_token
```

## File Structure

```
stacks/base/
├── docker-compose.yml   # Main compose file
├── .env.example         # Environment variable template
└── README.md            # This file

config/traefik/
├── traefik.yml          # Static config (entrypoints, providers, ACME)
└── dynamic/
    ├── tls.yml          # TLS cipher suites and options
    └── middlewares.yml  # Shared middlewares (auth, rate limit, security headers)
```

## Accessing Services

| Service | URL | Auth |
|---------|-----|------|
| Traefik Dashboard | `https://traefik.example.com` | Basic Auth (TRAEFIK_AUTH) |
| Portainer | `https://portainer.example.com` | Web UI (first run setup) |

> Replace `example.com` with your `DOMAIN` value.

## Connecting Other Stacks

Other stacks join the shared `proxy` network to be discovered by Traefik:

```yaml
# In another stack's docker-compose.yml
networks:
  proxy:
    external: true

services:
  my-service:
    networks:
      - proxy
    labels:
      traefik.enable: "true"
      traefik.http.routers.my-service.rule: "Host(`my-service.${DOMAIN}`)"
      traefik.http.routers.my-service.entrypoints: "websecure"
      traefik.http.routers.my-service.tls.certresolver: "letsencrypt"
```

## Watchtower — Automated Updates

Watchtower scans for updates **every day at 3:00 AM** and only updates containers that have the label:

```yaml
labels:
  com.centurylinklabs.watchtower.enable: "true"
```

To receive update notifications, set `WATCHTOWER_NOTIFICATION_URL` in `.env`. Supports Shoutrrr URL format (ntfy, Slack, Discord, email, Telegram).

## Troubleshooting

### Port 80/443 already in use

```bash
sudo lsof -i :80 -i :443
# Stop conflicting service (e.g., nginx, apache)
sudo systemctl stop nginx
```

### Traefik certificate not issued

1. Ensure DNS is pointing to your server
2. Check port 80 is publicly reachable: `curl http://yourdomain.com`
3. View Traefik logs: `docker compose logs traefik -f`
4. Check ACME debug: set `log.level: DEBUG` in `traefik.yml`

### Portainer showing 0 containers

Portainer needs access to the Docker socket. Ensure the volume mount is correct:
```bash
docker exec portainer ls /var/run/docker.sock
```

## Security Notes

- **Socket Proxy**: Traefik connects to Docker via socket-proxy (not direct socket mount), limiting API surface
- **Watchtower**: Only updates containers with explicit opt-in label
- **Traefik Dashboard**: Protected by HTTP Basic Auth — change default credentials!
- **TLS**: Automatically provisioned and renewed via Let's Encrypt
