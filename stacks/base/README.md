# Base Infrastructure Stack

Foundation services for the homelab: reverse proxy, Docker management, and automatic updates.

## Services

| Service | Image | Ports | Purpose |
|---------|-------|-------|---------|
| Traefik | `traefik:v3.1.6` | 80, 443 | Reverse proxy with auto HTTPS |
| Socket Proxy | `tecnativa/docker-socket-proxy:0.2.0` | 2375 (internal) | Secure Docker socket access |
| Portainer | `portainer/portainer-ce:2.21.3` | 9000 | Docker management UI |
| Watchtower | `containrrr/watchtower:1.7.1` | - | Automatic container updates |

## Quick Start

### 1. Create External Network

```bash
docker network create proxy
```

### 2. Generate Passwords

```bash
# Traefik Dashboard Basic Auth
htpasswd -nB admin | sed 's/\$/\$\$/g'

# Portainer Admin Password
htpasswd -nB admin
```

### 3. Configure Environment

```bash
cp .env.example .env
nano .env
```

Required variables:
- `DOMAIN` - Your domain name
- `ACME_EMAIL` - Email for Let's Encrypt
- `TRAEFIK_AUTH` - htpasswd hash for Traefik dashboard
- `PORTAINER_PASSWORD_HASH` - bcrypt hash for Portainer admin

### 4. Start Services

```bash
docker compose up -d
```

### 5. Access Services

- **Traefik Dashboard**: https://traefik.yourdomain.com
- **Portainer**: https://portainer.yourdomain.com

## Architecture

```
                    ┌─────────────────────────────────────────────────┐
                    │                   Internet                      │
                    └─────────────────────┬───────────────────────────┘
                                          │ 80/443
                                          ▼
                    ┌─────────────────────────────────────────────────┐
                    │                    Traefik                      │
                    │  - TLS termination (Let's Encrypt)             │
                    │  - Reverse proxy                               │
                    │  - Dashboard                                   │
                    └─────────────────────┬───────────────────────────┘
                                          │ proxy network
                    ┌─────────────────────┼───────────────────────────┐
                    │                     │                           │
                    ▼                     ▼                           ▼
            ┌───────────────┐   ┌───────────────┐          ┌───────────────┐
            │   Portainer   │   │  Other Stacks │          │   Watchtower  │
            │  (Docker UI)  │   │ (media, etc.) │          │  (Auto-update)│
            └───────┬───────┘   └───────────────┘          └───────────────┘
                    │
                    ▼
            ┌───────────────┐
            │ Socket Proxy  │
            │ (Docker API)  │
            └───────┬───────┘
                    │
                    ▼
            /var/run/docker.sock
```

## Configuration

### Traefik

#### Let's Encrypt

HTTP Challenge (default):
```bash
# Port 80 must be publicly accessible
ACME_EMAIL=admin@example.com
```

DNS Challenge (for internal networks):
```bash
# Uncomment in docker-compose.yml:
# - "--certificatesResolvers.myresolver.acme.dnsChallenge.provider=cloudflare"
DNS_PROVIDER=cloudflare
CF_DNS_API_TOKEN=your_token
```

#### Middlewares

Available in `config/traefik/dynamic/middlewares.yml`:
- `security-headers` - Add security headers
- `rate-limit` - Limit requests per minute
- `local-ip` - Restrict to local networks
- `redirect-www` - Redirect www to non-www
- `compress` - Enable gzip compression

Usage in other stacks:
```yaml
labels:
  - traefik.http.routers.myservice.middlewares=security-headers@file,rate-limit@file
```

### Portainer

First-time setup:
```bash
# Set admin password in .env
PORTAINER_PASSWORD_HASH=$(htpasswd -nB admin)

# Or use initial setup screen (if password hash not set)
# Access https://portainer.yourdomain.com and set password
```

### Watchtower

Configuration:
- Schedule: Daily at 3:00 AM (`0 0 3 * * *`)
- Labels required: `com.centurylinklabs.watchtower.enable=true`
- Notifications: Via ntfy

Enable auto-update for a container:
```yaml
labels:
  - com.centurylinklabs.watchtower.enable=true
```

## DNS Configuration

### Wildcard DNS

Point `*.yourdomain.com` to your server IP:

```
*.yourdomain.com.  IN  A  192.168.1.10
```

### Individual Records

Or create individual records:
```
traefik.yourdomain.com.    IN  A  192.168.1.10
portainer.yourdomain.com.  IN  A  192.168.1.10
```

## Integrating Other Stacks

All other stacks must:
1. Join the `proxy` network
2. Add `traefik.enable=true` label
3. Configure router and service labels

Example:
```yaml
services:
  myapp:
    image: myapp:latest
    networks:
      - proxy
    labels:
      - traefik.enable=true
      - "traefik.http.routers.myapp.rule=Host(`myapp.${DOMAIN}`)"
      - traefik.http.routers.myapp.entrypoints=websecure
      - traefik.http.routers.myapp.tls=true
      - traefik.http.routers.myapp.tls.certresolver=myresolver
      - traefik.http.services.myapp.loadbalancer.server.port=8080

networks:
  proxy:
    external: true
```

## Health Checks

```bash
# Traefik
docker exec traefik traefik healthcheck

# Portainer
curl -sf http://localhost:9000/api/status

# Socket Proxy
curl -sf http://localhost:2375/_ping

# Check all
docker ps --format "table {{.Names}}\t{{.Status}}"
```

## Troubleshooting

### Certificates Not Generated

```bash
# Check Traefik logs
docker logs traefik 2>&1 | grep -i acme

# Verify port 80 accessible
curl -I http://yourdomain.com/.well-known/acme-challenge/test

# Check acme.json
docker exec traefik cat /etc/traefik/acme.json | jq
```

### Dashboard Not Accessible

```bash
# Check Basic Auth
echo "admin:password" | htpasswd -nB admin

# Verify TRAEFIK_AUTH format
# Should be: admin:$2y$05$hash...
```

### Portainer Won't Start

```bash
# Check password hash
echo "Password hash: $PORTAINER_PASSWORD_HASH"

# Reset Portainer
docker compose down
docker volume rm homelab_portainer-data
docker compose up -d
```

### Socket Proxy Issues

```bash
# Test Docker API access
curl http://localhost:2375/containers/json

# Check allowed endpoints
docker logs socket-proxy
```

## Resource Requirements

| Service | Min Memory | Recommended |
|---------|------------|-------------|
| Traefik | 64 MB | 128-256 MB |
| Socket Proxy | 16 MB | 32 MB |
| Portainer | 64 MB | 128-256 MB |
| Watchtower | 16 MB | 32 MB |
| **Total** | **160 MB** | **320-576 MB** |

## Security

1. **Docker Socket**: Isolated via socket-proxy (read-only)
2. **TLS**: Automatic HTTPS with Let's Encrypt
3. **Auth**: Basic Auth for dashboard, password for Portainer
4. **Networks**: Services isolated in proxy network
5. **Headers**: Security headers enabled by default

## License

MIT
