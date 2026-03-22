# 🎬 Media Stack

> Complete media automation and streaming platform.

## 🎯 Bounty: [#2](../../issues/2) - $160 USDT

## 📋 Services

| Service | Purpose | Port |
|---------|---------|------|
| **Jellyfin** | Media streaming | 8096 |
| **Sonarr** | TV show automation | 8989 |
| **Radarr** | Movie automation | 7878 |
| **Prowlarr** | Indexer manager | 9696 |
| **qBittorrent** | Download client | 8080 |
| **Jellyseerr** | Request management | 5055 |

## 🚀 Quick Start

```bash
cp .env.example .env
nano .env  # Configure paths
docker compose -f stacks/media/docker-compose.yml up -d
```

## 🌐 Access URLs

- Jellyfin: `https://jellyfin.${DOMAIN}`
- Sonarr: `https://sonarr.${DOMAIN}`
- Radarr: `https://radarr.${DOMAIN}`
- Prowlarr: `https://prowlarr.${DOMAIN}`
- qBittorrent: `https://qbittorrent.${DOMAIN}`
- Jellyseerr: `https://requests.${DOMAIN}`

---

*Bounty: $160 USDT | Status: In Progress*
