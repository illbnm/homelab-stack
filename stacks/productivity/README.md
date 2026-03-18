# Productivity Stack

> Self-hosted productivity tools — git, docs, passwords, PDFs, whiteboards, and wikis.

## Services

| Service | URL | Description |
|---------|-----|-------------|
| [Gitea](https://gitea.io) | `git.{$DOMAIN}` | Lightweight Git hosting with CI/CD |
| [Vaultwarden](https://github.com/dani-garcia/vaultwarden) | `vault.{$DOMAIN}` | Bitwarden-compatible password manager |
| [Outline](https://www.getoutline.com) | `docs.{$DOMAIN}` | Team knowledge base & docs |
| [BookStack](https://www.bookstackapp.com) | `wiki.{$DOMAIN}` | Structured documentation wiki |
| [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) | `pdf.{$DOMAIN}` | Self-hosted PDF manipulation suite |
| [Excalidraw](https://excalidraw.com) | `draw.{$DOMAIN}` | Virtual collaborative whiteboard |

## Architecture

- **Reverse proxy:** All services exposed via Traefik (HTTPS, Let's Encrypt)
- **Databases:** Shared PostgreSQL (Gitea, Vaultwarden, Outline), MariaDB (BookStack), Redis (Outline)
- **Authentication:** Authentik OIDC — pre-configured for Outline and BookStack; ready to enable for Gitea
- **Registration:** Disabled on Gitea and Vaultwarden; Authentik handles user provisioning

## Quick Start

```bash
cp .env.example .env
# Edit .env — fill in DOMAIN, passwords, and secrets
docker compose up -d
```

## Required Environment Variables

See `.env.example` sections: `GITEA_*`, `VAULTWARDEN_*`, `OUTLINE_*`, `BOOKSTACK_*`.

## Notes

- Gitea uses shared PostgreSQL (`homelab-postgres`) — create DB/user before starting
- Outline requires both PostgreSQL and Redis
- Vaultwarden `ADMIN_TOKEN` must be set in `.env`
- Stirling PDF runs stateless (no login required by default)
- Excalidraw runs as a static SPA with no backend database

## Cost Estimate

~$170/year on a VPS — mainly disk and bandwidth for self-hosted alternatives to GitHub, 1Password, Notion, Confluence, and PDF tools.
