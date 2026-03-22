# 🌐 Network Stack

Home network infrastructure: DNS filtering, VPN access, dynamic DNS, and recursive DNS resolution.

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| AdGuard Home | `adguard/adguardhome:v0.107.52` | DNS filtering + ad blocking |
| WireGuard Easy | `ghcr.io/wg-easy/wg-easy:14` | VPN server with web UI |
| Cloudflare DDNS | `ghcr.io/favonia/cloudflare-ddns:1.14.0` | Dynamic DNS updater |
| Unbound | `mvance/unbound:1.21.1` | Recursive DNS resolver (DNSSEC) |

## Prerequisites

- Base stack running (`proxy` network)
- Port 53 available (run `fix-dns-port.sh` if on Ubuntu/Debian)
- Cloudflare API token with Zone:DNS:Edit permission

## Quick Start

```bash
# 1. Free port 53 (Ubuntu/Debian with systemd-resolved)
sudo ./scripts/fix-dns-port.sh --check
sudo ./scripts/fix-dns-port.sh --apply

# 2. Configure environment
cp stacks/network/.env.example stacks/network/.env
nano stacks/network/.env

# 3. Generate WireGuard admin password hash
docker run --rm ghcr.io/wg-easy/wg-easy:14 wgpw 'your-password'
# Paste output as WG_PASSWORD_HASH in .env

# 4. Start the stack
cd stacks/network
docker compose up -d

# 5. Check health
docker compose ps
```

## DNS Architecture

```
Client query
     │
     ▼
AdGuard Home :53 (ad filtering, caching)
     │
     ▼  (if not blocked, not cached)
Unbound :53 (recursive resolver, DNSSEC validation)
     │
     ▼
Root nameservers → TLD → Authoritative NS
```

**Privacy model**: No external DNS provider involved. Unbound resolves directly from root servers with DNSSEC validation. AdGuard Home filters and caches results.

## AdGuard Home Setup

### First Run
1. Visit `https://adguard.example.com`
2. Complete the setup wizard (ports are pre-configured)
3. Set admin username/password
4. **Upstream DNS**: set to `unbound:53` (internal network)

### Pre-configured blocklists
- AdGuard DNS filter
- AdAway Default Blocklist
- Steven Black's hosts
- Malware/hacked sites list

### Adding custom filters
Settings → Filters → Add blocklist (EasyList, OISD, etc.)

### Router DNS configuration
Point your router's DNS to your server's LAN IP. All devices will then use AdGuard Home automatically.

```
Primary DNS:   192.168.1.x  (your server's LAN IP)
Secondary DNS: 1.1.1.1      (fallback if server is down)
```

## WireGuard VPN

### Web UI
Access: `https://vpn.example.com`

### Add a client
1. Login to Web UI
2. Click "+" → enter client name
3. Download config or scan QR code with WireGuard app

### Split Tunneling vs Full Tunnel

**Full tunnel** (default — all traffic through VPN):
```
Allowed IPs: 0.0.0.0/0, ::/0
```

**Split tunnel** (only access LAN/internal services through VPN):
Edit client config:
```
[Peer]
AllowedIPs = 10.8.0.0/24, 192.168.1.0/24
```

### DNS inside VPN
VPN clients use AdGuard Home by default (`WG_DNS=10.8.0.1`). This gives you ad-free DNS everywhere when connected.

## Cloudflare DDNS

Updates DNS records every 5 minutes with your current public IP.

### Setup
1. Get Cloudflare API token: Dashboard → Profile → API Tokens → Create Token → "Edit zone DNS" template
2. Set `CF_API_TOKEN` and `CF_DOMAINS` in `.env`
3. Ensure the DNS records already exist in Cloudflare (DDNS updates existing records, doesn't create them)

### Multiple domains
```bash
CF_DOMAINS=vpn.example.com,home.example.com,*.example.com
```

## Resolving Port 53 Conflict

On Ubuntu 18.04+ and Debian with `systemd-networkd-wait-online`, `systemd-resolved` binds to `127.0.0.53:53`, preventing AdGuard Home from using port 53.

```bash
# Check current state
sudo ./scripts/fix-dns-port.sh --check

# Apply fix (non-destructive — uses drop-in config)
sudo ./scripts/fix-dns-port.sh --apply

# Undo fix if needed
sudo ./scripts/fix-dns-port.sh --restore
```

The script creates `/etc/systemd/resolved.conf.d/no-stub-listener.conf` with:
```ini
[Resolve]
DNSStubListener=no
```

And updates `/etc/resolv.conf` to use the real resolv.conf (not the stub).

## Required Open Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 53 | TCP+UDP | DNS |
| 853 | TCP | DNS over TLS |
| 51820 | UDP | WireGuard VPN |

## Network Architecture

```
Internet → Traefik (proxy network)
  ├── adguard.domain → adguardhome:80 (management UI)
  └── vpn.domain → wireguard:51821 (WireGuard web UI)

adguardhome:53 → unbound:53 (dns_internal network)

Cloudflare DDNS → host network (detects public IP)
```
