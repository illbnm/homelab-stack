# Base Infrastructure Stack

The foundation of HomeLab Stack. Deploy this stack before any other stack.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Traefik | 3.1.6 | `traefik.<DOMAIN>` | Reverse proxy and TLS termination |
| Portainer CE | 2.21.4 | `portainer.<DOMAIN>` | Docker management UI |
| Watchtower | 1.7.1 | n/a | Automatic container updates |
| Docker Socket Proxy | 0.2.0 | n/a | Constrained Docker API access for Traefik |

## Architecture

```text
Internet
  |
  +-- Traefik :80  -> redirects to HTTPS
  +-- Traefik :443 -> TLS termination
        |
        +-- traefik.<DOMAIN>   -> Traefik dashboard
        +-- portainer.<DOMAIN> -> Portainer
        +-- other stacks       -> containers attached to the proxy network

Traefik discovers Docker services through docker-socket-proxy instead of
mounting /var/run/docker.sock directly.
```

## Prerequisites

- Docker Engine 24 or newer with Docker Compose v2
- Ports 80 and 443 open on the host firewall
- A domain pointing to the server IP
- A populated root `.env` file

## Quick Start

From the repository root:

```bash
./install.sh
```

Manual launch:

```bash
docker network create proxy
touch config/traefik/acme.json
chmod 600 config/traefik/acme.json
./scripts/setup-env.sh
docker compose --env-file .env -f stacks/base/docker-compose.yml up -d
```

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | yes | Base domain, for example `home.example.com` |
| `ACME_EMAIL` | yes | Let's Encrypt notification email |
| `TRAEFIK_DASHBOARD_USER` | yes | Dashboard login username |
| `TRAEFIK_DASHBOARD_PASSWORD_HASH` | yes | Bcrypt password hash |
| `TZ` | yes | Timezone, for example `Asia/Shanghai` |

### Dashboard Password

Generate a bcrypt hash:

```bash
sudo apt-get install -y apache2-utils
htpasswd -nbB admin 'yourpassword' | sed 's/\$/\$\$/g'
```

Paste the result into `.env` as `TRAEFIK_DASHBOARD_PASSWORD_HASH`.
`scripts/setup-env.sh` also writes `config/traefik/.htpasswd` automatically.

If you edit `.env` manually, regenerate the htpasswd file:

```bash
printf '%s:%s\n' "$TRAEFIK_DASHBOARD_USER" \
  "$(printf '%s' "$TRAEFIK_DASHBOARD_PASSWORD_HASH" | sed 's/\$\$/\$/g')" \
  > config/traefik/.htpasswd
chmod 600 config/traefik/.htpasswd
```

### TLS Certificates

Traefik uses the `letsencrypt` resolver and stores certificates in
`config/traefik/acme.json`. The file must exist and have mode `600` before
Traefik starts.

The default resolver uses HTTP-01 challenge on port 80. A DNS resolver is also
present in `config/traefik/traefik.yml` for wildcard setups; edit the provider
and credentials before using it.

### Docker Socket Proxy

`docker-socket-proxy` exposes only the read-only Docker API endpoints Traefik
needs for service discovery:

- containers
- events
- info
- networks
- services
- tasks
- version

`POST=0` is set so Traefik cannot mutate Docker state through the proxy.
Portainer and Watchtower keep direct socket access because those services are
expected to manage containers and update images.

## Verification

```bash
docker compose --env-file .env -f stacks/base/docker-compose.yml config
docker compose --env-file .env -f stacks/base/docker-compose.yml up -d
docker compose --env-file .env -f stacks/base/docker-compose.yml ps
```

Expected results:

- Four containers start: Traefik, Portainer, Watchtower, Docker Socket Proxy.
- `http://<server-ip>` redirects to HTTPS.
- `https://traefik.<DOMAIN>` requires BasicAuth.
- `https://portainer.<DOMAIN>` opens Portainer.
- Other stacks attached to the `proxy` network are discovered by Traefik only
  when they set `traefik.enable=true`.
