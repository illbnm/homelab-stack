# Base Infrastructure Stack

> Base infrastructure layer for homelab - Traefik, Portainer, Watchtower

## 💰 Bounty

**$180 USDT** - See [BOUNTY.md](../../BOUNTY.md)

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| Traefik | `traefik:v3.1.6` | Reverse proxy + automatic HTTPS |
| Portainer CE | `portainer/portainer-ce:2.21.3` | Docker management UI |
| Watchtower | `containrrr/watchtower:1.7.1` | Container auto-update |
| Socket Proxy | `tecnativa/docker-socket-proxy:0.2.0` | Secure Docker socket isolation |

## Prerequisites

1. **Docker & Docker Compose** installed
2. **Cloudflare** account (for DNS Challenge)
3. **Domain** pointed to your server IP

## Quick Start

### 1. Create proxy network

```bash
docker network create proxy
```

### 2. Configure environment

```bash
cd stacks/base
cp .env.example .env
# Edit .env with your settings
```

### 3. Start services

```bash
docker compose up -d
```

### 4. Verify services

```bash
docker compose ps
```

Expected output:

```
NAME           IMAGE                              COMMAND                SERVICE    CREATED   STATUS    PORTS
portainer      portainer/portainer-ce:2.21.3   "/portainer"           portainer  ...       Up        9000/tcp, 9443/tcp
socket-proxy   tecnativa/docker-socket-proxy:0.2.0                       socket-…  ...       Up        2375/tcp
traefik        traefik:v3.1.6                  "/entrypoint.sh ..."   traefik   ...       Up        0.0.0.0:443->443/tcp, 0.0.0.0:80->80/tcp
watchtower     containrrr/watchtower:1.7.1      "/watchtower"          watchtower ...       Up        
```

### 5. Test Traefik routing

```bash
# Test HTTP to HTTPS redirect
curl -I http://localhost:80
# Expected: 301 redirect to HTTPS

# Test HTTPS (after DNS is configured)
curl -I https://traefik.yourdomain.com
# Expected: 200 or 401 (requires auth)
```

### 6. Test Portainer access

```bash
curl -I https://portainer.yourdomain.com
# Expected: 200 OK
```

## Configuration

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DOMAIN` | Your domain | `example.com` |
| `ACME_EMAIL` | Email for Let's Encrypt | `admin@example.com` |
| `CF_API_EMAIL` | Cloudflare email | `admin@example.com` |
| `CF_API_KEY` | Cloudflare Global API Key | `xxxxxxxx` |
| `TRAEFIK_AUTH` | Basic auth (user:hash) | See below |

### Generate Basic Auth Password

```bash
# Install apache2-utils (Debian/Ubuntu)
sudo apt install apache2-utils

# Generate password hash
htpasswd -nb admin yourpassword | cut -d: -f2

# Output: admin:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/
# Put this in TRAEFIK_AUTH
```

### Optional Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `Asia/Shanghai` | Timezone |
| `GOTIFY_URL` | - | Gotify server URL |
| `GOTIFY_TOKEN` | - | Gotify app token |
| `TRAEFIK_IMAGE` | `traefik:v3.1.6` | Traefik image (CN mirror) |
| `PORTAINER_IMAGE` | `portainer/portainer-ce:2.21.3` | Portainer image |
| `WATCHTOWER_IMAGE` | `containrrr/watchtower:1.7.1` | Watchtower image |

## Access URLs

After startup:

| Service | URL |
|---------|-----|
| Traefik Dashboard | `https://traefik.yourdomain.com` |
| Portainer | `https://portainer.yourdomain.com` |

## DNS Configuration

Create the following DNS records:

| Type | Name | Value |
|------|------|-------|
| A | traefik | YOUR_SERVER_IP |
| A | portainer | YOUR_SERVER_IP |

## Troubleshooting

### Check logs

```bash
# Traefik
docker logs traefik

# Portainer
docker logs portainer

# Watchtower
docker logs watchtower
```

### Common issues

1. **Port 80/443 already in use**
   - Stop existing services using these ports
   - Or modify port mappings in docker-compose.yml

2. **Cloudflare API error**
   - Ensure CF_API_KEY is Global API Key (not API Token)
   - Check API key permissions

3. **Traefik can't see containers**
   - Ensure containers are on `proxy` network
   - Check labels: `traefik.enable=true`

### CN Mirror (国内服务器)

如果服务器在中国大陆境内，可以使用国内镜像加速。在 `.env` 中设置：

```bash
TRAEFIK_IMAGE=traefik:v3.1.6
PORTAINER_IMAGE=portainer/portainer-ce:2.21.3
WATCHTOWER_IMAGE=containrrr/watchtower:1.7.1
```

## Integration

### Adding services to Traefik

Add these labels to your service in docker-compose.yml:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myservice.rule=Host(`myservice.${DOMAIN}`)"
  - "traefik.http.routers.myservice.entrypoints=websecure"
  - "traefik.http.routers.myservice.tls=true"
  - "traefik.http.services.myservice.loadbalancer.server.port=8080"
  - "com.centurylinklabs.watchtower.enable=true"  # Enable auto-update
```

## File Structure

```
stacks/base/
├── docker-compose.yml    # Main compose file
├── .env.example         # Environment template
└── README.md            # This file

config/traefik/
├── traefik.yml          # Static config
└── dynamic/
    ├── tls.yml          # TLS options
    └── middlewares.yml  # Middleware config
```

## License

MIT
