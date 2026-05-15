# Productivity Stack

Gitea + Vaultwarden + Outline + BookStack.

## Services

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| Gitea | 1.22.3 | `git.${DOMAIN}` | Git service |
| Vaultwarden | latest | `vault.${DOMAIN}` | Password manager |
| Outline | latest | `wiki.${DOMAIN}` | Knowledge base |
| BookStack | 24.10.0 | `books.${DOMAIN}` | Documentation wiki |

## Quick Start

```bash
docker compose -f stacks/productivity/docker-compose.yml up -d
```

Post-install: configure SMTP, OAuth, and admin accounts for each service.
