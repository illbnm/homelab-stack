# Network Stack

Network services for HomeLab Stack — DNS ad-blocking, VPN, dynamic DNS, and reverse proxy management.

## What's Included

| Service | Version | URL | Purpose |
|---------|---------|-----|---------|
| AdGuard Home | v0.107.55 | `adguard.<DOMAIN>` | DNS ad-blocker + encrypted DNS |
| WireGuard Easy | 14 | `vpn.<DOMAIN>` | VPN server with web UI |
| Cloudflare DDNS | 1.14.0 | — | Dynamic DNS updater |
| Nginx Proxy Manager | 2.11.3 | `npm.<DOMAIN>` | Reverse proxy management UI |

## Architecture

```
Internet
    │
    ├──► :53 (DNS)     ──► AdGuard Home (DNS filtering + ad block)
    ├──► :51820 (VPN)  ──► WireGuard Easy (VPN tunnel)
    │
    ▼ Traefik (from base stack)
    ├──► adguard.<DOMAIN>  ──► AdGuard admin UI
    ├──► vpn.<DOMAIN>      ──► WireGuard web UI
    └──► npm.<DOMAIN>      ──► NPM admin UI

Cloudflare DDNS ──► Updates DNS A record when IP changes
```

## Quick Start

```bash
# From repo root
cp .env.example .env
# Edit .env — set DOMAIN, WG_HOST, CF_API_TOKEN

# Start base stack first
cd stacks/base && docker compose up -d

# Start network stack
cd ../network
ln -sf ../../.env .env
docker compose up -d
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | — | Base domain |
| `TZ` | No | `Asia/Shanghai` | Timezone |
| `WG_HOST` | Yes | — | Public IP or domain for VPN |
| `WG_PASSWORD_HASH` | No | — | WireGuard UI password (bcrypt hash) |
| `CF_API_TOKEN` | Yes* | — | Cloudflare API token for DDNS |
| `CF_RECORD_NAME` | No | `${DOMAIN}` | DNS record to update |

*CF_API_TOKEN required only if using Cloudflare DDNS.

### AdGuard Home Setup

1. Visit `https://adguard.<DOMAIN>` on first launch
2. Set admin password and listening interfaces
3. Configure upstream DNS (e.g., `https://dns.alidns.com/dns-query` for CN, or `https://dns.quad9.net/dns-query`)
4. Add blocklists: Settings → DNS Blocklists → Add

### WireGuard VPN Setup

1. Visit `https://vpn.<DOMAIN>`
2. Create client profiles (one per device)
3. Scan QR code or download `.conf` file
4. Install WireGuard client on devices (iOS/Android/Windows/Mac)

**Default DNS** points to AdGuard Home (`adguardhome:53`) for ad-free DNS over VPN.

### Cloudflare DDNS

1. Create API token at https://dash.cloudflare.com/profile/api-tokens
2. Required permissions: Zone → DNS → Edit
3. Set `CF_API_TOKEN` in `.env`
4. The container auto-detects your public IP and updates the DNS record

### Nginx Proxy Manager

1. Visit `https://npm.<DOMAIN>`
2. Default login: `admin@example.com` / `changeme`
3. Change password immediately
4. Use for managing additional reverse proxy hosts outside Traefik

## DNS Configuration

Point your domain's nameservers to Cloudflare:

```
yourdomain.com  NS  →  Cloudflare nameservers
*.yourdomain.com  A  →  your server IP (auto-updated by DDNS)
```

AdGuard Home listens on port 53. For local devices, set DNS to your server's LAN IP.

## SSO Integration

All web UIs are protected by Authentik ForwardAuth. To enable:

1. Deploy the SSO stack (`stacks/sso/`)
2. The `authentik-forwardauth@docker` middleware is applied via labels

## CN Network Adaptation

AdGuard Home recommended upstream DNS for CN:
```
https://dns.alidns.com/dns-query
https://doh.pub/dns-query
```

If `CN_MODE=true`, the cloudflare-ddns and wireguard images may need mirror pulls:

```bash
# ghcr.io images need CN mirror
./scripts/cn-pull.sh
```

## Health Check Verification

```bash
# Check all services
docker compose ps --format "table {{.Name}}\t{{.Status}}"

# Individual checks
docker exec adguardhome wget -qO- http://localhost:3000
docker exec wireguard curl -sf http://localhost:51821/
docker exec nginx-proxy-manager curl -sf http://localhost:81/api/
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| DNS not resolving | Ensure port 53 not in use by host (`sudo systemctl stop systemd-resolved`) |
| WireGuard can't connect | Check `WG_HOST` is correct public IP; open port 51820/udp on firewall |
| DDNS not updating | Verify `CF_API_TOKEN` has DNS Edit permission |
| AdGuard + Traefik conflict | AdGuard uses port 53 only; Traefik uses 80/443 — no conflict |
| NPM shows wrong cert | NPM manages its own certs; for Traefik-managed hosts, use Traefik labels instead |
| VPN clients can't reach LAN | Add `10.0.0.0/8,192.168.0.0/16` to `WG_ALLOWED_IPS` |
