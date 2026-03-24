# Base Infrastructure Stack

Core infrastructure services that all other stacks depend on.

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| Socket Proxy | `tecnativa/docker-socket-proxy:0.2.0` | Secure Docker API isolation |
| Traefik | `traefik:v3.1.6` | Reverse proxy + auto HTTPS |
| Portainer | `portainer/portainer-ce:2.21.4` | Docker management UI |
| Watchtower | `containrrr/watchtower:1.7.1` | Automatic container updates |

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │              Internet                    │
                    └─────────────────┬───────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────────┐
                    │            Traefik (443)                 │
                    │  - TLS termination (Let's Encrypt)       │
                    │  - Reverse proxy                         │
                    │  - Rate limiting                         │
                    └─────────────────┬───────────────────────┘
                                      │
              ┌───────────────────────┼───────────────────────┐
              │                       │                       │
              ▼                       ▼                       ▼
    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
    │   Portainer     │    │   Watchtower    │    │   Socket Proxy  │
    │  (Management)   │    │  (Auto-update)  │    │  (API Gateway)  │
    └─────────────────┘    └─────────────────┘    └────────┬────────┘
                                                          │
                                                          ▼
                                              ┌─────────────────────┐
                                              │   Docker Socket     │
                                              │  (read-only access) │
                                              └─────────────────────┘
```

## Security: Docker Socket Proxy

The Docker socket proxy provides a secure layer between services and the Docker socket, restricting API access to only what's needed:

### Allowed Endpoints (Read-Only)
- `CONTAINERS` - List/inspect containers
- `NETWORKS` - List/inspect networks
- `EVENTS` - Subscribe to Docker events
- `TASKS` - List/inspect Swarm tasks
- `INFO` - System information

### Blocked Endpoints (Security)
- `IMAGES` - Image management
- `VOLUMES` - Volume management
- `BUILD` - Build images
- `COMMIT` - Create images
- `EXEC` - Execute commands in containers
- `SECRETS` - Access secrets
- `SWARM` - Swarm management
- `CONTAINERS_CREATE/START/STOP/KILL/DELETE` - Container lifecycle

### Why This Matters
- **Principle of Least Privilege**: Services only get the access they need
- **Attack Surface Reduction**: Even if Traefik is compromised, container manipulation is blocked
- **Audit Trail**: Socket proxy logs all API requests

## Quick Start

```bash
# 1. Create proxy network
docker network create proxy

# 2. Setup environment
cp .env.example .env
# Edit .env with your domain and email

# 3. Create ACME file for certificates
mkdir -p config/traefik
touch config/traefik/acme.json
chmod 600 config/traefik/acme.json

# 4. Start the stack
docker compose up -d

# 5. Verify all services are healthy
docker compose ps
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DOMAIN` | Your domain name | Required |
| `ACME_EMAIL` | Email for Let's Encrypt | Required |
| `TZ` | Timezone | `UTC` |
| `TRAEFIK_AUTH` | Basic auth for dashboard | Optional |
| `WATCHTOWER_NOTIFICATION_URL` | Notification webhook | Optional |

## Verification

### Check Socket Proxy
```bash
# Test that socket proxy is working
curl http://localhost:2375/version

# Should return Docker version info
```

### Check Traefik
```bash
# Access dashboard
https://traefik.yourdomain.com

# Check health
curl http://localhost:8080/ping
```

### Check Portainer
```bash
# Access UI
https://portainer.yourdomain.com

# First-time setup: set admin password within 5 minutes
```

### Check Watchtower
```bash
# View logs
docker logs watchtower

# Check schedule
docker inspect watchtower --format '{{.Config.Env}}' | grep SCHEDULE
```

## Troubleshooting

### Socket Proxy Not Healthy
```bash
# Check logs
docker logs docker-socket-proxy

# Verify Docker socket is accessible
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock:ro alpine ls /var/run/docker.sock
```

### Traefik Can't Discover Containers
```bash
# Check Traefik can reach socket proxy
docker exec traefik wget -qO- http://docker-socket-proxy:2375/version

# Check network connectivity
docker network inspect proxy
```

### Certificate Issues
```bash
# Check ACME file permissions
ls -la config/traefik/acme.json

# Should be -rw-------
chmod 600 config/traefik/acme.json

# Restart Traefik to retry
docker restart traefik
```

## Related Issues
- Issue #1: Base Infrastructure Bounty

## License
MIT