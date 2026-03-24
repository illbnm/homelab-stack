# Network Stack

DNS filtering, VPN, dynamic DNS, and recursive DNS for HomeLab.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| AdGuard Home | 0.107.55 | `adguard.<DOMAIN>` | DNS-level ad blocking |
| WireGuard Easy | 13 | `wg.<DOMAIN>` | VPN server with web UI |
| Cloudflare DDNS | 1.15.1 | — | Dynamic DNS updater |
| Unbound | 1.22.0 | `localhost:5335` | Recursive DNS resolver |

## Architecture

```
Client → WireGuard VPN
           ↓
        AdGuard Home (filtering)
           ↓
        Unbound (recursive DNS)
           ↓
        Root DNS servers

Cloudflare DDNS → Cloudflare API (keep A record updated)
```

## Prerequisites

- Base infrastructure stack running (Traefik + proxy network)
- Cloudflare API token with `DNS:Edit` permission for DDNS
- UDP port 51820 open on router/firewall for WireGuard

## Quick Start

```bash
cd stacks/network
cp .env.example .env
# Edit .env with your credentials
docker compose up -d
```

## Configuration

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain |
| `TZ` | ✅ | Timezone |
| `WG_HOST` | ✅ | Public IP or domain for WireGuard |
| `WG_PASSWORD` | ✅ | Web UI password |
| `WG_PORT` | ❌ | Default: `51820` |
| `CF_API_TOKEN` | ✅ | Cloudflare API token |
| `CF_RECORD_NAME` | ✅ | Domain record to update |

## Post-Deploy Setup

1. **WireGuard**: Open `https://wg.<DOMAIN>` — create clients and download configs
2. **AdGuard Home**: Open `https://adguard.<DOMAIN>` — run initial setup wizard, point upstream to `unbound:5335`
3. **Unbound**: Pre-configured as recursive resolver, no setup needed
4. **Cloudflare DDNS**: Auto-starts, logs show updates

## Health Checks

```bash
docker compose ps
```
