# SSO Stack — Authentik Unified Identity

Provides OIDC/SAML single sign-on for all HomeLab services via [Authentik](https://goauthentik.io/).

## Architecture

```
Browser → Traefik (443) → ForwardAuth → authentik-server:9000

Services (6 integrated):
  auth.DOMAIN       → Authentik Admin + User Portal
  grafana.DOMAIN    → Grafana       (native OIDC)
  git.DOMAIN        → Gitea         (ForwardAuth)
  docs.DOMAIN       → Outline       (native OIDC)
  nextcloud.DOMAIN  → Nextcloud     (ForwardAuth)
  ai.DOMAIN         → Open WebUI    (native OIDC + ForwardAuth)
  portainer.DOMAIN  → Portainer     (ForwardAuth)
  prometheus.DOMAIN → Prometheus    (ForwardAuth)

Internal: authentik-server/worker → postgresql:5432 + redis:6379
```

## Authentication Strategy

| Service | Method | Notes |
|---------|--------|-------|
| Grafana | Native OIDC | Full OAuth2 with role mapping via groups |
| Outline | Native OIDC | Built-in OIDC via env vars |
| Open WebUI | Native OIDC + ForwardAuth | OAuth2 env vars + middleware |
| Gitea | ForwardAuth | Configure OIDC via Admin UI post-deploy |
| Nextcloud | ForwardAuth | Install `user_oidc` app via `occ` |
| Portainer | ForwardAuth | No native OIDC env var support |
| Prometheus | ForwardAuth | No native OAuth2 support |

## User Groups

Created automatically by `setup-authentik.sh`:

| Group | Purpose |
|-------|---------|
| `homelab-admins` | Full access — Portainer, Traefik dashboard, all admin panels |
| `homelab-users` | Standard access — productivity, storage, AI services |
| `media-users` | Media streaming — Jellyfin, Sonarr, Radarr |

## Quick Start

```bash
cd stacks/sso
cp .env.example .env && nano .env

# Generate secrets
sed -i "s|^AUTHENTIK_SECRET_KEY=.*|AUTHENTIK_SECRET_KEY=$(openssl rand -base64 32)|" .env
sed -i "s|^AUTHENTIK_POSTGRES_PASSWORD=.*|AUTHENTIK_POSTGRES_PASSWORD=$(openssl rand -hex 16)|" .env
sed -i "s|^AUTHENTIK_REDIS_PASSWORD=.*|AUTHENTIK_REDIS_PASSWORD=$(openssl rand -hex 16)|" .env
sed -i "s|^AUTHENTIK_BOOTSTRAP_TOKEN=.*|AUTHENTIK_BOOTSTRAP_TOKEN=$(openssl rand -hex 32)|" .env

docker compose up -d
# Wait ~60s, then:
../../scripts/setup-authentik.sh
../../scripts/verify-sso-setup.sh
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AUTHENTIK_SECRET_KEY` | YES | `openssl rand -base64 32` |
| `AUTHENTIK_POSTGRES_PASSWORD` | YES | PostgreSQL password |
| `AUTHENTIK_REDIS_PASSWORD` | YES | Redis password |
| `AUTHENTIK_BOOTSTRAP_EMAIL` | YES | Initial admin email |
| `AUTHENTIK_BOOTSTRAP_PASSWORD` | YES | Initial admin password |
| `AUTHENTIK_BOOTSTRAP_TOKEN` | YES | API token for setup script |
| `AUTHENTIK_DOMAIN` | YES | `auth.yourdomain.com` |

## Post-Deploy Service Configuration

### Gitea (manual)
Admin → Authentication Sources → Add → OpenID Connect
Use `GITEA_OAUTH_CLIENT_ID` / `GITEA_OAUTH_CLIENT_SECRET` from `.env`

### Nextcloud (manual)
```bash
docker exec -it nextcloud php occ app:install user_oidc
docker exec -it nextcloud php occ config:app:set user_oidc provider_name --value="Authentik"
docker exec -it nextcloud php occ config:app:set user_oidc client_id --value="$NEXTCLOUD_OAUTH_CLIENT_ID"
docker exec -it nextcloud php occ config:app:set user_oidc client_secret --value="$NEXTCLOUD_OAUTH_CLIENT_SECRET"
docker exec -it nextcloud php occ config:app:set user_oidc issuer --value="https://auth.DOMAIN/application/o/nextcloud/"
```

## Health Check

```bash
docker compose ps
curl -sf https://auth.DOMAIN/-/health/ready/
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Container exits | Check `AUTHENTIK_SECRET_KEY` is set |
| DB connection refused | Wait 30s; check password match |
| OIDC redirect mismatch | Ensure redirect URIs match exactly |
| ForwardAuth loop | Use `authentik-server:9000` internally |
| `ghcr.io` timeout | Uncomment CN mirror in docker-compose.yml |
