# Productivity Stack — Gitea + Vaultwarden + Outline + Stirling PDF + BookStack

## Services

| Service | Version | Subdomain | Auth Mode |
|---|---|---|---|
| Gitea | `gitea/gitea:1.22.2` | `git.${DOMAIN}` | Authentik OIDC (Registration disabled) |
| Gitea Actions Runner | `gitea/act_runner:0.2.10` | Internal | Runner Token |
| Vaultwarden | `vaultwarden/server:1.32.0` | `vault.${DOMAIN}` | HTTPS + `ADMIN_TOKEN` (Signups disabled) |
| Outline | `outlinewiki/outline:0.80.2` | `wiki.${DOMAIN}` | Authentik OIDC + Shared PG/Redis + MinIO S3 |
| Stirling PDF | `frooodle/s-pdf:0.30.2` | `pdf.${DOMAIN}` | Traefik + Authentik ForwardAuth |
| BookStack | `lscr.io/linuxserver/bookstack:24.05.4` | `docs.${DOMAIN}` | Authentik OIDC + Shared MariaDB |

## Quick Start

```bash
cp stacks/productivity/.env.example stacks/productivity/.env
docker compose -f stacks/productivity/docker-compose.yml up -d
```
