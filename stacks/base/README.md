# Base Infrastructure Stack

The foundation of HomeLab Stack. Must be deployed **before any other stack**.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Traefik | 3.1.6 | `traefik.<DOMAIN>` | Reverse proxy + TLS termination |
| Portainer CE | 2.21.4 | `portainer.<DOMAIN>` | Docker management UI |
| Watchtower | 1.7.1 | — | Automatic container updates |
| Docker Socket Proxy | 0.2.0 | — | Secure Docker API access |

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
    ├──► traefik.<DOMAIN>    → Traefik Dashboard (BasicAuth protected)
    └──► *..<DOMAIN>         → Other stacks via 'proxy' network

[Docker Socket Proxy] ← Traefik/Watchtower connect here
    │
    └──► /var/run/docker.sock (read-only)

[proxy] ← shared Docker network — all stacks attach here
```

## Prerequisites

- Docker >= 24.0 with Compose v2 plugin
- Ports 80 and 443 open on your firewall
- A domain pointing to your server's IP (A record or wildcard)
- `./scripts/setup-env.sh` completed (creates `.env` and `acme.json`)

## Quick Start

```bash
# From repo root — recommended (runs check-deps + setup-env first)
./install.sh

# Or manually:
cd stacks/base
ln -sf ../../.env .env       # share root .env

# Create required files
touch ../../config/traefik/acme.json
chmod 600 ../../config/traefik/acme.json

# Create the proxy network (required for all stacks)
docker network create proxy

# Start the stack
docker compose up -d
```

## Configuration

### Environment Variables (`.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain, e.g. `home.example.com` |
| `ACME_EMAIL` | ✅ | Email for Let's Encrypt notifications |
| `TZ` | ✅ | Timezone, e.g. `Asia/Shanghai` or `UTC` |
| `WATCHTOWER_NOTIFICATION_URL` | — | Notification URL for updates (Gotify/ntfy) |

### DNS Configuration

Point your domain to your server's IP:

```
# A record (required)
@           A       YOUR_SERVER_IP

# Or wildcard (recommended)
*.home      A       YOUR_SERVER_IP

# Then set DOMAIN=home.example.com
```

### Generate Dashboard Password

```bash
# Install htpasswd (Debian/Ubuntu)
sudo apt-get install -y apache2-utils

# Generate password file
htpasswd -nbB admin 'yourpassword' > ../../config/traefik/dynamic/.htpasswd
```

### TLS Certificates

Traefik uses Let's Encrypt HTTP-01 challenge by default:
- Certificates are automatically requested when a service is accessed
- Stored in `config/traefik/acme.json`
- Auto-renewed before expiry

For DNS-01 challenge (wildcard certificates), edit `config/traefik/traefik.yml`:

```yaml
certificatesResolvers:
  letsencrypt-dns:
    acme:
      email: "your-email@example.com"
      dnsChallenge:
        provider: cloudflare  # or route53, digitalocean, etc.
```

## Verification

After starting the stack:

```bash
# Check all containers are healthy
docker compose ps

# Verify HTTP → HTTPS redirect
curl -I http://your-server-ip/
# Should return 301 redirect to https://

# Access Traefik dashboard
https://traefik.yourdomain.com

# Access Portainer
https://portainer.yourdomain.com
# First visit: set admin password within 5 minutes
```

## Watchtower Configuration

Watchtower automatically updates containers with the label `com.centurylinklabs.watchtower.enable=true`.

- **Schedule**: Daily at 3:00 AM (configurable via `WATCHTOWER_SCHEDULE`)
- **Scope**: Only labeled containers (prevents unwanted updates)
- **Cleanup**: Removes old images after update

### Notification Integration

Set `WATCHTOWER_NOTIFICATION_URL` for update notifications:

```bash
# Gotify (recommended)
WATCHTOWER_NOTIFICATION_URL=gotify://gotify.yourdomain.com/YOUR_TOKEN

# ntfy
WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.yourdomain.com/watchtower

# Email
WATCHTOWER_NOTIFICATION_URL=smtp://user:pass@mail.yourdomain.com:587/from@yourdomain.com/to@yourdomain.com
```

## Security Features

### Docker Socket Proxy

The `docker-socket-proxy` container provides secure, read-only access to the Docker API:
- Traefik only reads container/service/network info
- No write access to Docker API
- Portainer has direct socket access (needed for management)

### Network Isolation

All services run on the external `proxy` network:
- Services can only communicate through Traefik
- No direct container-to-container access from outside

### TLS Hardening

- TLS 1.2 minimum (TLS 1.3 recommended)
- Strong cipher suites only
- HSTS enabled (1 year, include subdomains)
- Security headers applied globally

## Troubleshooting

### Traefik won't start

```bash
# Check acme.json permissions
ls -la ../../config/traefik/acme.json
# Should be: -rw------- (600)

# Fix if needed
chmod 600 ../../config/traefik/acme.json
```

### Certificates not issued

```bash
# Check Traefik logs
docker compose logs traefik | grep -i acme

# Ensure port 80 is accessible from internet
# Let's Encrypt needs to reach your server for HTTP-01 challenge
```

### Can't access dashboard

```bash
# Verify DNS resolution
dig traefik.yourdomain.com

# Check .htpasswd file exists
cat ../../config/traefik/dynamic/.htpasswd

# Verify container is healthy
docker compose ps traefik
```

## File Structure

```
stacks/base/
├── docker-compose.yml       # Main compose file
├── docker-compose.local.yml # Local dev overrides
├── .env.example             # Environment template
└── README.md                # This file

config/traefik/
├── traefik.yml              # Static configuration
├── acme.json                # Let's Encrypt certificates (auto-generated)
└── dynamic/
    ├── tls.yml              # TLS options
    ├── middlewares.yml      # Security middlewares
    ├── authentik.yml        # SSO integration
    └── .htpasswd            # Dashboard auth (create this)
```
