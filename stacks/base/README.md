# Base Infrastructure Stack

Core gateway and management layer powering the homelab infrastructure. Provides centralized ingress, automated SSL/TLS certificate management, Docker container administration, automated container updates, and Docker socket security isolation.

## Services Architecture

| Service | Version | Access Domain / URL | Description |
|---|---|---|---|
| **Traefik** | `v3.1.6` | `https://traefik.${DOMAIN}` | Edge reverse proxy, SSL termination & HTTP-to-HTTPS redirect |
| **Portainer CE** | `2.21.3` | `https://portainer.${DOMAIN}` | Web-based container and volume management dashboard |
| **Watchtower** | `1.7.1` | Automated 3 AM Cron | Updates containers marked with `watchtower.enable=true` |
| **Docker Socket Proxy** | `0.2.0` | `tcp://docker-proxy:2375` | Read-only security isolation for Docker daemon socket |

## Docker Network Setup

All other application stacks connect to Traefik via the shared `proxy` external network:

```bash
docker network create proxy || true
```

## Traefik Dashboard Protection

The dashboard is secured by default with HTTP Basic Auth. Generate your credentials:

```bash
# Example with htpasswd:
echo $(htpasswd -nb admin my_super_secret_password) | sed -e s/\$/\$\$/g
```

## Quick Start

```bash
docker network create proxy || true
cp stacks/base/.env.example stacks/base/.env
docker compose -f stacks/base/docker-compose.yml up -d
```
