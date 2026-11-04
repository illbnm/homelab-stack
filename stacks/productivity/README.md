# Productivity Stack

Comprehensive self-hosted productivity ecosystem including Git code repository, Bitwarden-compatible password vault, collaborative team knowledge base, Swiss-army PDF tool, and virtual whiteboard.

## Services Included

| Service | Version | URL / Domain | Description |
|---|---|---|---|
| **Gitea** | `1.22.2` | `https://git.${DOMAIN}` | Git repository management & lightweight DevOps |
| **Vaultwarden** | `1.32.0` | `https://vault.${DOMAIN}` | Bitwarden-compatible password vault with WebSockets |
| **Outline** | `0.80.2` | `https://wiki.${DOMAIN}` | Markdown team knowledge base and wiki |
| **Stirling PDF** | `0.30.2` | `https://pdf.${DOMAIN}` | 50+ local privacy-preserving PDF operations |
| **Excalidraw** | `latest` | `https://draw.${DOMAIN}` | Real-time collaborative sketching & diagramming |

## Integrations

- **Databases**: Gitea and Outline connect to the shared PostgreSQL 16 instance.
- **Cache**: Outline uses shared Redis 7.4 for sessions and fast caching.
- **SSL / TLS**: Vaultwarden enforces mandatory HTTPS via Traefik for browser extension cryptography.
- **Authentik OIDC Ready**: Built with support for external OIDC authentication.

## Quick Start

```bash
# 1. Fill environment variables
cp stacks/productivity/.env.example stacks/productivity/.env

# 2. Deploy productivity stack
docker compose -f stacks/productivity/docker-compose.yml up -d
```
