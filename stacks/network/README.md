# Network Stack

AdGuard Home + WireGuard + Nginx Proxy Manager for network management.

## Services

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| AdGuard Home | 0.107.55 | `adguard.<DOMAIN>` | DNS filtering + ad blocking |
| WireGuard | 1.0.20210914 | — | VPN server |
| Nginx Proxy Manager | 2.11.3 | `npm.<DOMAIN>` | Reverse proxy fallback |

## Quick Start

```bash
docker compose -f stacks/network/docker-compose.yml up -d
```

Note: WireGuard requires kernel modules. On Synology/DSM use `--privileged` flag.
