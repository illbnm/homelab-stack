# Base Infrastructure Stack

The base stack must be running before the other service stacks. It provides the shared `proxy` network, public HTTPS entrypoint, Docker management UI, and label-scoped automatic updates.

## Services

| Service | Image | URL | Purpose |
|---------|-------|-----|---------|
| Traefik | `traefik:v3.6.1` | `https://traefik.<DOMAIN>` | Reverse proxy, HTTPS redirect, TLS termination, dashboard |
| Portainer CE | `portainer/portainer-ce:2.21.3` | `https://portainer.<DOMAIN>` | Docker management UI |
| Watchtower | `containrrr/watchtower:1.7.1` | none | Daily label-scoped image updates |
| Docker Socket Proxy | `tecnativa/docker-socket-proxy:0.2.0` | internal only | Read-only Docker API isolation for Traefik |

## Network Model

```
Internet
  |
  v
Traefik :80/:443  --->  proxy network  --->  public services with traefik.enable=true
  |
  v
socket-proxy network  --->  docker-socket-proxy  --->  /var/run/docker.sock
```

- `proxy` is an external Docker network shared by every stack that Traefik routes.
- `homelab-socket-proxy` is an internal-only network used by Traefik to read Docker metadata.
- Traefik never mounts `/var/run/docker.sock`; it talks to `tcp://socket-proxy:2375` and the proxy exposes only read endpoints needed for container discovery.
- Portainer and Watchtower keep direct Docker socket access because they are Docker management/update tools.

## DNS

Create DNS records that point at the server running Docker:

| Record | Target |
|--------|--------|
| `traefik.<DOMAIN>` | server public IP |
| `portainer.<DOMAIN>` | server public IP |
| `*.<DOMAIN>` | server public IP, optional but useful for later stacks |

For HTTP-01 certificates, ports `80/tcp` and `443/tcp` must reach the server from the public internet. For private or wildcard deployments, use the DNS challenge resolver described below.

## Environment

For standalone base-stack deployment:

```bash
cd stacks/base
cp .env.example .env
```

Required values:

| Variable | Description |
|----------|-------------|
| `DOMAIN` | Base domain, for example `home.example.com` |
| `ACME_EMAIL` | Let's Encrypt account email |
| `TRAEFIK_AUTH` | `htpasswd` BasicAuth user/hash for the Traefik dashboard |
| `TZ` | Container timezone, for example `Asia/Shanghai` |

Generate the dashboard credential:

```bash
htpasswd -nbB admin 'change-this-password' | sed -e 's/\$/\$\$/g'
```

Paste the full `admin:...` output into `TRAEFIK_AUTH`.

## Certificates

The default resolver is `letsencrypt`, which uses HTTP-01 on port 80:

```env
TRAEFIK_CERT_RESOLVER=letsencrypt
```

For DNS challenge, set the router resolver to `letsencryptdns` and provide the matching Lego provider credentials. The included example uses Cloudflare:

```env
TRAEFIK_CERT_RESOLVER=letsencryptdns
ACME_DNS_PROVIDER=cloudflare
CF_DNS_API_TOKEN=your-cloudflare-dns-token
```

Certificates are stored in `config/traefik/acme.json`. Create it before the first start:

```bash
touch ../../config/traefik/acme.json
chmod 600 ../../config/traefik/acme.json
```

## Start

```bash
docker network create proxy 2>/dev/null || true
docker compose up -d
```

Expected containers:

- `docker-socket-proxy`
- `traefik`
- `portainer`
- `watchtower`

Check status:

```bash
docker compose ps
curl -I http://127.0.0.1
curl -I https://traefik.${DOMAIN}/dashboard/
curl -I https://portainer.${DOMAIN}/api/status
```

The plain HTTP request should redirect to HTTPS. The Traefik dashboard should require BasicAuth. Portainer should respond through Traefik and will ask for first-login setup in the UI.

## Watchtower Notifications

Watchtower runs at 03:00 daily and only updates containers labeled with:

```yaml
com.centurylinklabs.watchtower.enable: "true"
```

Notification delivery uses Shoutrrr URLs. Set one of these after the Notifications stack is available or when using an external endpoint:

```env
WATCHTOWER_NOTIFICATIONS=shoutrrr
WATCHTOWER_NOTIFICATION_URL=ntfy://ntfy.example.com/homelab-updates
# or
WATCHTOWER_NOTIFICATION_URL=gotify://gotify.example.com/token
```

## Local Validation

Traefik uses strict SNI, so `curl -H "Host: ..."` against `https://127.0.0.1` will fail unless the TLS certificate store has a certificate for that host. Use one of these local paths instead.

For a quick provider/dashboard check without HTTPS or BasicAuth, use the local override:

```bash
TRAEFIK_DASHBOARD_PORT=18080 docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
curl -sS http://127.0.0.1:18080/api/http/routers
```

For a production-router check without public DNS, add a temporary local certificate and use `--resolve` so SNI matches the router host:

```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
  -keyout ../../config/traefik/dynamic/local-key.pem \
  -out ../../config/traefik/dynamic/local-cert.pem \
  -subj "/CN=${DOMAIN}" \
  -addext "subjectAltName=DNS:${DOMAIN},DNS:traefik.${DOMAIN},DNS:portainer.${DOMAIN}"

cat > ../../config/traefik/dynamic/local.generated.yml <<'YAML'
tls:
  certificates:
    - certFile: /dynamic/local-cert.pem
      keyFile: /dynamic/local-key.pem
YAML

curl --noproxy '*' -k -I \
  --resolve "traefik.${DOMAIN}:443:127.0.0.1" \
  "https://traefik.${DOMAIN}/dashboard/"

curl --noproxy '*' -k -I \
  --resolve "portainer.${DOMAIN}:443:127.0.0.1" \
  "https://portainer.${DOMAIN}/api/status"
```

## Troubleshooting

- `network proxy declared as external, but could not be found`: run `docker network create proxy`.
- Traefik dashboard returns `401`: BasicAuth is working; authenticate with the username used in `TRAEFIK_AUTH`.
- Let's Encrypt errors on local domains are expected; use a real public DNS record or the DNS challenge resolver.
- If `docker-socket-proxy` is unhealthy, confirm Docker is available on the host and `/var/run/docker.sock` exists.
