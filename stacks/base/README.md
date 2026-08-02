# Base Infrastructure Stack

This is the core foundation stack for the homelab. All other stacks route traffic and resolve certificates through this layer.

## Included Services

- **Traefik v3**: Edge Router / Reverse Proxy. Automatically routes incoming traffic to the right containers based on Docker labels and auto-generates TLS certificates via Let's Encrypt.
- **Portainer CE**: Web UI to manage Docker environments.
- **Watchtower**: Automates container updates. Scans daily at 3:00 AM for containers with the label `com.centurylinklabs.watchtower.enable=true`.
- **Docker Socket Proxy**: Enhances security by restricting access to the Docker socket. Traefik and Portainer communicate with this proxy instead of directly mounting `/var/run/docker.sock`.

## Prerequisites

Before starting this stack, you MUST manually create the external `proxy` network:

```bash
docker network create proxy
```

## Setup & Configuration

1. Copy `.env.example` to `.env` and configure:
   - `DOMAIN`: Your root domain (e.g., `example.com`).
   - `ACME_EMAIL`: Your email for Let's Encrypt notices.
   - `TRAEFIK_AUTH`: Basic Auth string for the Traefik dashboard.

   To generate a basic auth string, use `htpasswd` (or an online generator):
   ```bash
   htpasswd -nb admin mysecurepassword
   ```

2. Start the stack:
   ```bash
   docker compose up -d
   ```

3. Ensure DNS records for `traefik.yourdomain.com` and `portainer.yourdomain.com` point to your homelab's IP.

## Security

- Port 80 automatically redirects to HTTPS (Port 443).
- The `traefik` dashboard is secured via basic auth (using the `TRAEFIK_AUTH` variable) and the `authTraefik` middleware defined in `../../config/traefik/dynamic/middlewares.yml`.
- We utilize `docker-socket-proxy` to ensure if a frontend container is compromised, it only has read access to the Docker API and cannot take over the host.