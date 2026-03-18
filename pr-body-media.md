## Media Stack Implementation

Implements **Bounty #2: Media Stack ($160 USDT)**

### Services (6 containers)

| Service | Image | Subdomain |
|---------|-------|-----------|
| Jellyfin | jellyfin/jellyfin:10.9.11 | media.DOMAIN |
| Jellyseerr | fallenbagel/jellyseerr:2.1.1 | requests.DOMAIN |
| Sonarr | linuxserver/sonarr:4.0.11 | sonarr.DOMAIN |
| Radarr | linuxserver/radarr:5.8.1 | radarr.DOMAIN |
| Prowlarr | linuxserver/prowlarr:1.22.0 | prowlarr.DOMAIN |
| qBittorrent | linuxserver/qbittorrent:4.6.7 | bt.DOMAIN |

### Key Features

- **TRaSH Guides directory layout** — single DATA_ROOT mount enables hardlinks
- **Proper startup ordering** — depends_on with service_healthy conditions
- **All 6 services** with health checks, Traefik labels, Let's Encrypt TLS
- **Jellyseerr** added (not in original skeleton) for request management
- **.env.example** with documented TRaSH Guides directory structure
- **README.md** — complete docs: architecture, setup, per-service config steps, Authentik SSO, troubleshooting, CN mirrors

### Acceptance Criteria

- [x] docker compose up -d starts all 6 services
- [x] All services have healthcheck
- [x] Traefik reverse proxy with subdomain routing
- [x] TRaSH Guides directory structure for hardlinks
- [x] Sonarr/Radarr → qBittorrent connection documented
- [x] Jellyfin media library setup documented
- [x] README complete with FAQ
- [x] No hardcoded passwords/secrets

Generated/reviewed with: claude-opus-4-6
