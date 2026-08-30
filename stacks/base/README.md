# Base Infrastructure Stack

This stack provides the foundational reverse proxy, Docker management UI, and auto-update services for the homelab.

## Services

| Service | Image | Purpose |
|---------|-------|--------|
| Traefik | `traefik:v3.1.6` | Reverse proxy + automatic HTTPS |
| Portainer CE | `portainer/portainer-ce:2.21.3` | Docker management UI |
| Watchtower | `containrrr/watchtower:1.7.1` | Automatic container updates |
| Socket Proxy | `tecnativa/docker-socket-proxy:0.2.0` | Secure Docker socket isolation |

## Prerequisites

1. Create the external `proxy` network before deploying:
   ```bash
   docker network create proxy
   ```
2. Copy `.env.example` to `.env` and configure variables.
3. Generate `TRAEFIK_AUTH` using `htpasswd`:
   ```bash
   htpasswd -nB user
   ```

## DNS Configuration

Create A/AAAA records pointing to your server IP:

- `*.example.com` → `<server-ip>` (wildcard recommended)
- Or individual records: `traefik.example.com`, `portainer.example.com`

For Let's Encrypt HTTP challenge, ensure port 80 is publicly accessible.
For DNS challenge, configure your provider credentials in `traefik.yml`.

## Certificate Configuration

By default, this stack uses Let's Encrypt HTTP-01 challenge.
To switch to DNS-01 challenge, edit `config/traefik/traefik.yml` and uncomment/configure the DNS resolver section.

Certificates are stored in the `traefik-certs` Docker volume.

## Deployment

```bash
cd stacks/base
docker compose up -d
```

## Verification

- [ ] All 4 containers are running and healthy
- [ ] `http://<ip>:80` redirects to HTTPS
- [ ] `https://traefik.<domain>` shows dashboard (requires auth)
- [ ] `https://portainer.<domain>` loads Portainer UI
- [ ] Other stacks on `proxy` network are discoverable by Traefik
