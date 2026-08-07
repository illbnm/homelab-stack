# Productivity Stack

Self-hosted productivity suite: code hosting, password management, knowledge base, PDF tools, and whiteboard.

## Services

| Service | Port | Purpose |
|---------|------|---------|
| **PostgreSQL 16** | 5432 (internal) | Shared database |
| **Redis 7** | 6379 (internal) | Caching + Outline session store |
| **Gitea** | 3000, 2222 (SSH) | Git code hosting |
| **Vaultwarden** | 8080 | Password manager (Bitwarden compatible) |
| **Outline** | 3001 | Team knowledge base |
| **Stirling PDF** | 8081 | PDF processing (merge, split, convert, OCR) |
| **Excalidraw** | 8082 | Collaborative whiteboard |

## Quick Start

```bash
# 1. Create PostgreSQL databases
docker compose up -d postgres
docker compose exec postgres createdb -U admin gitea
docker compose exec postgres createdb -U admin outline

# 2. Generate secrets for Outline
openssl rand -hex 32  # SECRET_KEY
openssl rand -hex 32  # UTILS_SECRET

# 3. Configure HTTPS via Nginx Proxy Manager (see network stack)

# 4. Start all
docker compose up -d
```

## Access After Startup

- Gitea: http://localhost:3000
- Vaultwarden: http://localhost:8080
- Outline: http://localhost:3001
- Stirling PDF: http://localhost:8081
- Excalidraw: http://localhost:8082

## Security Notes

- Change ALL placeholder passwords before production use
- Vaultwarden requires HTTPS (browser extension requirement)
- Gitea registration is disabled by default
- Use Authentik OIDC for SSO across all services
