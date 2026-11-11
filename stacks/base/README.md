# Base Infrastructure Stack (Traefik v3 + Socket Proxy + Portainer + Watchtower)

Core reverse proxy, automated TLS termination, Docker socket isolation, and container management for Homelab Stack.

## Pinned Services

| Service | Image | Description |
|---------|-------|-------------|
| `socket-proxy` | `tecnativa/docker-socket-proxy:0.2.0` | Read-only Docker API proxy isolating `/var/run/docker.sock` |
| `traefik` | `traefik:v3.1.6` | HTTPS ingress, Let's Encrypt DNS-01 wildcard certs, Prometheus metrics |
| `portainer` | `portainer/portainer-ce:2.21.4` | Web container management UI connected via `socket-proxy` |
| `watchtower` | `containrrr/watchtower:1.7.1` | Scheduled opt-in container image updater |

## Deployment

```bash
docker network create homelab-net || true
cp stacks/base/.env.example stacks/base/.env
docker compose -f stacks/base/docker-compose.yml up -d
```
