# Stacks

Each directory is a standalone, production-ready Docker Compose stack.

> **All stacks require the [Base Infrastructure](../stacks/base/) stack to be deployed first** — it provides Traefik (reverse proxy), Portainer, and the shared `proxy` Docker network.

---

## Catalog

| Stack | Services | Traefik Routes |
|-------|----------|----------------|
| [base/](base/) | Traefik, Portainer CE, Watchtower | `traefik.<DOMAIN>`, `portainer.<DOMAIN>` |
| [ai/](ai/) | Ollama, Open WebUI, A1111 Stable Diffusion WebUI | `ollama.<DOMAIN>`, `ai.<DOMAIN>`, `sd.<DOMAIN>` |
| [backup/](backup/) | Restic, Rclone | — (CLI-driven) |
| [dashboard/](dashboard/) | Homepage, Heimdall | `home.<DOMAIN>` |
| [databases/](databases/) | PostgreSQL, Redis, MariaDB | — (internal only) |
| [home-automation/](home-automation/) | Home Assistant, Node-RED, Mosquitto, Zigbee2MQTT, ESPHome | `ha.<DOMAIN>` |
| [media/](media/) | Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, Jellyseerr | `jellyfin.<DOMAIN>`, `prowlarr.<DOMAIN>`, `bt.<DOMAIN>` |
| [monitoring/](monitoring/) | Grafana, Prometheus, Loki, Alertmanager, Uptime Kuma | `grafana.<DOMAIN>`, `uptime.<DOMAIN>` |
| [network/](network/) | AdGuard Home, WireGuard Easy, Cloudflare DDNS, Nginx Proxy Manager | `adguard.<DOMAIN>`, `warp.<DOMAIN>` |
| [notifications/](notifications/) | Gotify, Ntfy, Apprise | `gotify.<DOMAIN>`, `ntfy.<DOMAIN>`, `apprise.<DOMAIN>` |
| [productivity/](productivity/) | Gitea, Vaultwarden, Outline, BookStack | `git.<DOMAIN>`, `vault.<DOMAIN>`, `docs.<DOMAIN>` |
| [sso/](sso/) | Authentik (OIDC/SSO) | `auth.<DOMAIN>` |
| [storage/](storage/) | Nextcloud, MinIO, FileBrowser, Syncthing | `cloud.<DOMAIN>`, `minio.<DOMAIN>` |

---

## Usage

### Launching a Stack

```bash
cd stacks/<name>

# Link the root .env (required for DOMAIN and other shared vars)
ln -sf ../../.env .env

# Launch
docker compose up -d

# Check status
docker compose ps
```

Or use the stack manager from the repo root:

```bash
./scripts/stack-manager.sh start ai
./scripts/stack-manager.sh stop ai
./scripts/stack-manager.sh restart ai
```

### Updating a Stack

```bash
cd stacks/<name>
docker compose pull
docker compose up -d
```

### Removing a Stack

```bash
cd stacks/<name>
docker compose down -v   # -v removes named volumes (deletes data!)
docker compose down      # preserves volumes
```

---

## Shared Architecture

All stacks attach to the **`proxy`** Docker network managed by Traefik in the base stack. This means:

- Every service with `traefik.enable=true` labels is automatically reachable at its configured `Host()` rule
- TLS is auto-provisioned via Let's Encrypt (HTTP-01 challenge)
- All traffic enters through port 443 (HTTP redirects to HTTPS)

### Shared Networks

| Network | Purpose |
|---------|---------|
| `proxy` | Traefik-facing — all user-facing services attach here |
| `databases` | Internal — shared PostgreSQL / Redis / MariaDB for app stacks |

### Shared Environment Variables

Variables defined in the **root `.env`** are inherited by all stacks:

| Variable | Description |
|----------|-------------|
| `DOMAIN` | Base domain, e.g. `home.example.com` |
| `TZ` | Timezone, e.g. `Asia/Shanghai` |
| `PUID` / `PGID` | Linux user/group IDs for file permissions |
| `ACME_EMAIL` | Let's Encrypt notification email |
