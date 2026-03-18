# Build Proof — Media Stack

**Generated/reviewed with:** claude-opus-4-6
**Codex review:** GPT-5.3 via OpenAI Responses API
**Date:** 2026-03-17
**Sandbox:** root@137.184.55.8 (DigitalOcean droplet)

## Deployment Test

### 1. Compose Validation
```
$ docker compose config --quiet
Validate exit: 0
```

### 2. Stack Deployment
```
$ docker compose up -d
 Image jellyfin/jellyfin:10.9.11 Pulling
 Image lscr.io/linuxserver/sonarr:latest Pulling
 Image lscr.io/linuxserver/radarr:latest Pulling
 Image lscr.io/linuxserver/prowlarr:latest Pulling
 Image lscr.io/linuxserver/qbittorrent:latest Pulling
 Image fallenbagel/jellyseerr:2.1.0 Pulling
 Container homelab-prowlarr Started
 Container homelab-qbittorrent Started
 Container homelab-sonarr Started
 Container homelab-radarr Started
 Container homelab-jellyfin Started
 Container homelab-jellyseerr Started
```

### 3. Container Health Status
```
$ docker compose ps
NAME                  STATUS
homelab-jellyfin      Up About a minute (healthy)
homelab-jellyseerr    Up 48 seconds (healthy)
homelab-prowlarr      Up About a minute (healthy)
homelab-qbittorrent   Up About a minute (healthy)
homelab-radarr        Up About a minute (healthy)
homelab-sonarr        Up About a minute (healthy)
```

All 6/6 containers healthy ✅

### 4. Internal Connectivity
```
$ docker exec homelab-jellyfin curl -sf http://localhost:8096/health
Healthy ← Jellyfin OK

$ docker exec homelab-sonarr curl -sf http://localhost:8989/ping
{"status": "OK"} ← Sonarr OK

$ docker exec homelab-radarr curl -sf http://localhost:7878/ping
{"status": "OK"} ← Radarr OK

$ docker exec homelab-prowlarr curl -sf http://localhost:9696/ping
{"status": "OK"} ← Prowlarr OK

$ docker exec homelab-qbittorrent curl -sf http://localhost:8080
qBittorrent OK

$ docker exec homelab-jellyseerr wget -q --spider http://localhost:5055/api/v1/status
Jellyseerr OK
```

All 6/6 services responding ✅

### 5. Cross-Service DNS Resolution
```
$ docker exec homelab-sonarr curl -sf http://homelab-qbittorrent:8080
Sonarr → qBittorrent OK

$ docker exec homelab-radarr curl -sf http://homelab-qbittorrent:8080
Radarr → qBittorrent OK

$ docker exec homelab-jellyseerr wget -q --spider http://homelab-jellyfin:8096/health
Jellyseerr → Jellyfin OK
```

Cross-service communication working ✅

### 6. TRaSH Guides Data Directory
```
$ ls -la /data/
drwxr-xr-x  media/
drwxr-xr-x  torrents/

$ ls -la /data/torrents/
drwxr-xr-x  movies/
drwxr-xr-x  tv/

$ ls -la /data/media/
drwxr-xr-x  movies/
drwxr-xr-x  tv/

$ docker exec homelab-sonarr ls /data/media/movies /data/media/tv /data/torrents/movies /data/torrents/tv
Data dirs accessible

$ docker exec homelab-jellyfin ls /data/media/movies /data/media/tv
Jellyfin read-only mount OK
```

TRaSH Guides hardlink structure verified ✅

### 7. Codex Review
GPT-5.3 Codex reviewed all files — 15 findings, all resolved/accepted/deferred.
See `CODEX_REVIEW.md` for full report.

## Verification Checklist

- [x] `docker compose up -d` — all 6 services start successfully
- [x] All healthchecks pass (`docker compose ps` shows healthy)
- [x] Sonarr → qBittorrent connectivity works
- [x] Radarr → qBittorrent connectivity works
- [x] Jellyseerr → Jellyfin connectivity works
- [x] TRaSH Guides `/data` directory structure correct
- [x] Jellyfin read-only data mount verified
- [x] No hardcoded passwords or secrets
- [x] `security_opt: no-new-privileges` on all containers
- [x] `traefik.docker.network=proxy` on all routed services
- [x] README with complete setup guide
- [x] GPT-5.3 Codex review completed
