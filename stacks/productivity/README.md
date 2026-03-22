# 💼 Productivity Stack

> Self-hosted productivity and collaboration tools.

## 🎯 Bounty: [#5](../../issues/5) - $170 USDT

## 📋 Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| **Gitea** | `gitea/gitea:1.22.0` | 3000 | Git hosting (GitHub alternative) |
| **Vaultwarden** | `dani-garcia/vaultwarden:1.32.0` | 8000 | Bitwarden-compatible password manager |
| **Outline** | `docker.getoutline.com/outlinewiki/outline:v0.80.2` | 3001 | Knowledge base / Wiki |
| **BookStack** | `lscr.io/linuxserver/bookstack:24.05.2` | 6875 | Documentation platform |
| **Stirling-PDF** | `frooodle/s-pdf:0.30.0` | 8080 | PDF manipulation tools |
| **IT-Tools** | `corentinth/it-tools:2024.3.3` | 8081 | Developer utilities |

## 🚀 Quick Start

```bash
cp .env.example .env
nano .env  # Configure passwords and domains
docker compose -f stacks/productivity/docker-compose.yml up -d
```

## 🌐 Access URLs

- Gitea: `https://gitea.${DOMAIN}`
- Vaultwarden: `https://vault.${DOMAIN}`
- Outline: `https://outline.${DOMAIN}`
- BookStack: `https://wiki.${DOMAIN}`
- Stirling-PDF: `https://pdf.${DOMAIN}`
- IT-Tools: `https://tools.${DOMAIN}`

## 🔐 Security Notes

- Change all default passwords immediately
- Enable 2FA on all services
- Configure OAuth with Authentik for SSO
- Regular backups of databases

---

*Bounty: $170 USDT | Status: In Progress*
