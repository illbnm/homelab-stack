# Network Stack

DNS filtering, VPN, dynamic DNS, and recursive DNS for HomeLab.

## Services

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| AdGuard Home | v0.107.52 | `adguard.<DOMAIN>` | DNS filtering & ad blocking |
| WireGuard Easy | 14 | `wg.<DOMAIN>` | VPN server with Web UI |
| Cloudflare DDNS | 1.14.0 | — | Dynamic DNS (IPv4 + IPv6) |
| Unbound | 1.21.1 | — | Recursive DNS resolver |

## Architecture

```
Client → AdGuard Home (port 53) → Unbound (recursive) → Internet
WireGuard clients → AdGuard Home (split tunnel DNS)
```

## Prerequisites

- Base infrastructure stack running (Traefik + proxy network)
- Port 53 must be free — run `scripts/fix-dns-port.sh --check` first

## Quick Start

```bash
cd stacks/network
cp .env.example .env
scripts/fix-dns-port.sh --apply  # if systemd-resolved uses port 53
docker compose up -d
```

## Configuration

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | ✅ | Base domain |
| `TZ` | ✅ | Timezone |
| `WG_HOST` | ❌ | Default: `DOMAIN` |
| `WG_DNS` | ❌ | Default: `10.8.0.1` |
| `CF_API_TOKEN` | ✅ | Cloudflare API token |
| `CF_DOMAINS` | ❌ | Default: `DOMAIN` |

## fix-dns-port.sh

```bash
scripts/fix-dns-port.sh --check    # Check if port 53 is in use
scripts/fix-dns-port.sh --apply    # Disable systemd-resolved listener
scripts/fix-dns-port.sh --restore  # Restore original config
```

## Health Checks

```bash
docker compose ps
```
