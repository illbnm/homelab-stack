# 💼 Productivity Stack (Gitea, Vaultwarden, Outline, Stirling PDF, Excalidraw)

> Self-hosted team collaboration, source control, password vault, knowledge base, and drawing suite.

## 📦 Services

| Service | Image | Subdomain | Description |
|---|---|---|---|
| **Gitea** | `gitea/gitea:1.22.2` | `git.${DOMAIN}` | Git repository hosting |
| **Vaultwarden** | `vaultwarden/server:1.32.0` | `vault.${DOMAIN}` | Bitwarden-compatible password manager |
| **Outline** | `outlinewiki/outline:0.80.2` | `docs.${DOMAIN}` | Collaborative markdown knowledge base |
| **Stirling PDF** | `frooodle/s-pdf:0.30.2` | `pdf.${DOMAIN}` | Comprehensive local PDF processing suite |
| **Excalidraw** | `excalidraw/excalidraw:latest-sha` | `draw.${DOMAIN}` | Virtual whiteboard for wireframing |

## 🔑 Authentication & Single Sign-On (Authentik OIDC)
- **Gitea:** Configured via `GITEA__oauth2__ENABLE=true` and Authentik custom application.
- **Outline:** Uses Authentik OIDC issuer at `https://auth.${DOMAIN}/application/o/outline/`.
- **Vaultwarden:** Open registration disabled via `SIGNUPS_ALLOWED=false`; invites managed via `ADMIN_TOKEN`.
