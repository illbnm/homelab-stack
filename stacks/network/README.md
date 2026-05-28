# Network Stack

AdGuard Home + WireGuard + Nginx Proxy Manager for network management.

## Services

| Service | Image | Purpose | Access |
|---------|-------|---------|--------|
| AdGuard Home | adguard/adguardhome:latest | DNS filtering & ad blocking | https://adguard.${DOMAIN} |
| WireGuard | weejewel/wg-easy | VPN server | UDP :51820 |
| NPM | jc21/nginx-proxy-manager | Reverse proxy GUI | https://npm.${DOMAIN} |

## Quick Start

```bash
# 1. Prerequisites
docker network create proxy

# 2. Configure
cp stacks/network/.env.example stacks/network/.env
# Edit .env with your domain and passwords

# 3. Deploy
docker compose -f stacks/network/docker-compose.yml up -d
```

## DNS Configuration

Set AdGuard Home (container IP: 172.20.0.2) as your primary DNS server for network-wide filtering.
