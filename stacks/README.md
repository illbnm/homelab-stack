# HomeLab Stacks

All stacks depend on the **Base Infrastructure** stack as the foundation.

## Stack Overview

| Stack | Directory | Description |
|-------|-----------|-------------|
| **Base Infrastructure** | `base/` | Traefik, Portainer, Watchtower 鈥?must be deployed first |
| [AI](ai/) | `ai/` | Ollama, Open WebUI, LocalAI, n8n |
| [Backup](backup/) | `backup/` | Automatic backups for volumes and databases |
| [Dashboard](dashboard/) | `dashboard/` | Homepage, Heimdall |
| [Databases](databases/) | `databases/` | PostgreSQL, Redis, MariaDB |
| [Home Automation](home-automation/) | `home-automation/` | Home Assistant, Node-RED, Mosquitto, Zigbee2MQTT |
| [Media](media/) | `media/` | Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent |
| [Monitoring](monitoring/) | `monitoring/` | Grafana, Prometheus, Loki, Alertmanager |
| [Network](network/) | `network/` | AdGuard Home, WireGuard, Cloudflare DDNS |
| [Notifications](notifications/) | `notifications/` | Gotify, Ntfy, Apprise |
| [Productivity](productivity/) | `productivity/` | Gitea, Vaultwarden, Outline, Stirling-PDF |
| [SSO](sso/) | `sso/` | Authentik (OIDC/SAML provider) |
| [Storage](storage/) | `storage/` | Nextcloud, MinIO, FileBrowser, Syncthing |

## Deployment Order

```
1. Base Infrastructure (stacks/base/)  鈫?ALWAYS FIRST
   鈹溾攢鈹€ Traefik (reverse proxy + TLS)
   鈹溾攢鈹€ Portainer (container management)
   鈹斺攢鈹€ Watchtower (auto-updates)

2. SSO (stacks/sso/)                     鈫?RECOMMENDED SECOND
   鈹斺攢鈹€ Authentik (unified identity)

3. Other stacks (in any order)
```

## Shared Resources

All stacks use the following shared resources managed by the base stack:

- **Docker Network:** `proxy` 鈥?Traefik-accessible network for all stacks
- **Environment:** `.env` at repo root 鈥?shared env vars across all stacks
- **Config:** `config/` 鈥?shared Traefik, Prometheus, Grafana configs

## Managing Stacks

```bash
# From repo root
./scripts/stack-manager.sh start base
./scripts/stack-manager.sh start sso
./scripts/stack-manager.sh start media

# Or directly
cd stacks/<stack-name>
docker compose up -d
```

See [README](../README.md) for the full architecture diagram.
