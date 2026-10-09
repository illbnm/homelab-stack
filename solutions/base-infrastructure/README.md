# Base Infrastructure Stack

Complete Docker infrastructure with Traefik reverse proxy, Portainer management UI, and Watchtower auto-updates.

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| Traefik | `traefik:v3.1.6` | Reverse proxy + automatic HTTPS |
| Portainer CE | `portainer/portainer-ce:2.21.3` | Docker management UI |
| Watchtower | `containrrr/watchtower:1.7.1` | Automatic container updates |
| Docker Socket Proxy | `tecnativa/docker-socket-proxy:0.2.0` | Secure Docker socket isolation |

## Prerequisites

1. **Docker and Docker Compose** installed
2. **Domain name** with DNS access
3. **Ports 80 and 443** available

## DNS Configuration

Create the following DNS A records pointing to your server IP:

```
traefik.example.com    → YOUR_SERVER_IP
portainer.example.com  → YOUR_SERVER_IP
*.example.com          → YOUR_SERVER_IP  (wildcard, optional)
```

Replace `example.com` with your actual domain.

## Setup Instructions

### 1. Clone and Configure

```bash
git clone <repository-url>
cd stacks/base

# Copy environment template
cp .env.example .env

# Edit .env with your settings
nano .env
```

### 2. Generate Traefik Dashboard Password

```bash
# Install htpasswd (if not available)
# Ubuntu/Debian: sudo apt-get install apache2-utils
# CentOS/RHEL: sudo yum install httpd-tools

# Generate password hash
htpasswd -nB admin
# Output: admin:$apr1$xyz$hashedpassword

# Copy the entire output (including "admin:") to .env
# TRAEFIK_AUTH=admin:$apr1$xyz$hashedpassword
```

### 3. Create External Network

```bash
docker network create proxy
```

### 4. Configure Certificates

**Option A: HTTP Challenge (default)**
- Requires ports 80/443 accessible from internet
- Works with most DNS providers
- Automatic certificate renewal

**Option B: DNS Challenge (for internal networks)**

Edit `config/traefik/traefik.yml`:

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      # ... existing config ...
      dnsChallenge:
        provider: cloudflare  # or route53, digitalocean, etc.
        resolvers:
          - "1.1.1.1:53"
          - "8.8.8.8:53"
```

Add DNS provider credentials to `.env`:

```bash
# For Cloudflare
CF_DNS_API_TOKEN=your_token_here
CF_ZONE_API_TOKEN=your_zone_token
```

### 5. Start Services

```bash
docker compose up -d
```

### 6. Verify Deployment

```bash
# Check all containers are running
docker compose ps

# Check logs
docker compose logs -f

# Test HTTP → HTTPS redirect
curl -I http://traefik.yourdomain.com
# Should return 301 redirect to HTTPS

# Test Traefik dashboard
curl -I https://traefik.yourdomain.com
# Should prompt for credentials

# Test Portainer
curl -I https://portainer.yourdomain.com
# Should return 200 OK
```

## Health Checks

All services include health checks:

```bash
# Check service health
docker compose ps

# Expected output:
# NAME                  STATUS
# traefik               Up (healthy)
# portainer             Up (healthy)
# watchtower            Up
# docker-socket-proxy   Up (healthy)
```

## Security Features

### Docker Socket Isolation

The Docker socket is isolated using `docker-socket-proxy`:
- Traefik only has read access to containers, networks, services, and tasks
- Write operations (POST) are disabled
- Sensitive APIs (secrets, auth, system) are blocked

### Traefik Security

- Automatic HTTPS with Let's Encrypt
- HTTP → HTTPS redirect
- HSTS enabled (31536000 seconds)
- Security headers (X-Frame-Options, X-Content-Type-Options, etc.)
- Dashboard protected with Basic Auth
- TLS 1.2+ only with strong cipher suites

### Watchtower Security

- Only updates containers with label `com.centurylinklabs.watchtower.enable=true`
- Runs daily at 3:00 AM
- Cleans up old images after updates

## Adding Services to the Stack

To add a new service that uses Traefik:

```yaml
services:
  my-service:
    image: my-image:latest
    networks:
      - proxy  # Connect to external proxy network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myservice.rule=Host(`myservice.example.com`)"
      - "traefik.http.routers.myservice.entrypoints=websecure"
      - "traefik.http.routers.myservice.tls=true"
      - "traefik.http.routers.myservice.tls.certresolver=letsencrypt"
      - "com.centurylinklabs.watchtower.enable=true"  # Enable auto-updates

networks:
  proxy:
    external: true
```

## Troubleshooting

### Certificate Issues

```bash
# Check certificate status
docker compose exec traefik cat /letsencrypt/acme.json

# Force certificate renewal
docker compose restart traefik
```

### Network Issues

```bash
# Verify proxy network exists
docker network ls | grep proxy

# Recreate network if missing
docker network create proxy
```

### Dashboard Access

```bash
# Reset dashboard password
htpasswd -nB admin
# Update .env with new hash
docker compose restart traefik
```

## Maintenance

### Update Stack

```bash
docker compose pull
docker compose up -d
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f traefik
```

### Backup

```bash
# Backup Portainer data
docker run --rm -v portainer_portainer-data:/data -v $(pwd):/backup alpine tar czf /backup/portainer-backup.tar.gz /data

# Backup Traefik certificates
docker run --rm -v base_traefik-certificates:/letsencrypt -v $(pwd):/backup alpine tar czf /backup/traefik-backup.tar.gz /letsencrypt
```

## Acceptance Criteria

- [x] `docker compose up -d` starts all 4 containers
- [x] All containers pass health checks
- [x] `http://any-ip:80` redirects to HTTPS
- [x] `traefik.example.com` accessible with password protection
- [x] `portainer.example.com` accessible
- [x] Other stack containers discoverable via `proxy` network
- [x] README includes DNS and certificate configuration

## License

MIT
